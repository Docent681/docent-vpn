from flask import Flask, redirect, render_template, url_for, request, session
from flask_mailman import EmailMessage
from services import code_generate, create_key, delete_user_key
from config import Config
from extensions import db, migrate, mail
from models import RequestAnswer, User, Request, Key, Log
import logging

app = Flask(__name__)
app.config.from_object(Config)

db.init_app(app)
mail.init_app(app)
migrate.init_app(app, db)


# ------------------------------------------------------------
# Вспомогательная функция для записи лога
# ------------------------------------------------------------
def write_log(username, action):
    """Добавляет запись в таблицу logs."""
    log_entry = Log.create_log(username, action)
    db.session.add(log_entry)
    db.session.commit()


# ------------------------------------------------------------
# Действия при прямом входе по URL
# ------------------------------------------------------------
@app.route('/')
def index():
    return redirect(url_for('login'))


# ------------------------------------------------------------
# Страница регистрации нового пользователя
# ------------------------------------------------------------
@app.route('/register', methods=['GET', 'POST'])
def register():
    error = None
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        password_repeat = request.form.get('password_repeat')

        if password != password_repeat:
            error = "Введенные пароли не совпадают"
        elif User.query.filter((User.username == username) & (User.is_confirmed == True)).first() is not None:
            error = "Пользователь под данным логином уже существует в системе"
        elif User.query.filter((User.email == email) & (User.is_confirmed == True)).first() is not None:
            error = "Пользователь под данной почтой уже существует в системе"
        else:
            user = User.query.filter(
                ((User.username == username) & (User.is_confirmed == False)) |
                ((User.email == email) & (User.is_confirmed == False))
            ).first()
            if user is None:
                user = User()
            user.set_username(username)
            user.set_email(email)
            user.set_password(password)
            user.set_is_admin(False)
            db.session.add(user)
            db.session.commit()

            # В зависимости от доступности почты выполняем разные сценарии
            if Config.IS_MAIL_COOKED:
                user.set_is_confirmed(True)
                write_log(username, "Успешная регистрация (без подтверждения почты)")
                return redirect(url_for('login', error=error))
            else:
                user.set_is_confirmed(False)
                session['user_id'] = user.get_id()
                code = code_generate()
                session['code'] = code
                msg = EmailMessage(
                    "Код регистрации нового пользователя Docent VPN",
                    f"Используйте ваш персональный код {code} для регистрации в клиенте Docent VPN",
                    Config.MAIL_USERNAME,
                    [f"{email}"]
                )
                msg.send()
                return redirect(url_for('verify', error=error))

        # Если есть ошибка, пишем лог и показываем форму
        if error:
            write_log(username if username else 'неизвестный', f"Ошибка регистрации: {error}")
        return render_template('register.html', error=error)

    return render_template('register.html', error=error)


# ------------------------------------------------------------
# Страница подтверждения регистрации
# ------------------------------------------------------------
@app.route('/verify', methods=['GET', 'POST'])
def verify():
    error = None
    if request.method == 'POST':
        user_code = request.form.get("user_code")
        code = session.get('code')
        user_id = session.get('user_id')
        user = User.query.get(user_id)

        if user_code == code:
            if user:
                if user.get_is_confirmed():
                    session.clear()
                    return redirect(url_for('register', error=error))
                user.set_is_confirmed(True)
                db.session.commit()
                write_log(user.get_username(), "Подтверждение регистрации (код верен)")
                session.clear()
                return redirect(url_for('login', error=error))
            else:
                error = "Произошла ошибка. Попробуйте зарегистрироваться еще раз"
                db.session.delete(user)
                db.session.commit()
                session.clear()
                return redirect(url_for('register', error=error))
        else:
            # Неверный код
            error = "Вы неверно ввели код подтверждения. Попробуйте зарегистрироваться заново"
            write_log(user.get_username() if user else 'неизвестный', "Неверный код подтверждения")
            db.session.delete(user)
            db.session.commit()
            session.clear()
            return redirect(url_for('register', error=error))

    return render_template('verify.html', error=error)


# ------------------------------------------------------------
# Выход из системы
# ------------------------------------------------------------
@app.route('/logout')
def logout():
    current_user = session.get('current_user_login')
    if current_user:
        write_log(current_user, "Выход из системы")
    session.clear()
    return redirect(url_for('login'))


# ------------------------------------------------------------
# Страница входа пользователя / администратора
# ------------------------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        user_type = request.form.get('user_type')

        user = User.query.filter((User.username == username) | (User.email == username)).first()
        if user is None:
            error = "Неверный логин или пароль"
        elif not user.check_password(password):
            error = "Неверный логин или пароль"
        elif not user.get_is_confirmed():
            error = "Пожалуйста, подтвердите регистрацию по коду из письма"
        elif user_type == 'admin_choice' and not user.is_admin:
            error = "У вас нет прав администратора"

        if error:
            write_log(username if username else 'неизвестный', f"Ошибка входа: {error}")
            return render_template('login.html', error=error)

        # Успешный вход
        session.clear()
        session['current_user_login'] = username

        if user_type == 'user_choice':
            write_log(username, "Вход в систему как пользователь")
            return redirect(url_for('user_dashboard', error=error))
        else:
            write_log(username, "Вход в систему как администратор")
            return redirect(url_for("admin_dashboard", error=error))

    return render_template('login.html', error=error)


# ------------------------------------------------------------
# Личный кабинет пользователя
# ------------------------------------------------------------
@app.route('/user_dashboard', methods=['GET'])
def user_dashboard():
    error = None
    current_user = session.get('current_user_login')
    if not current_user:
        return redirect(url_for('login', error="Необходимо войти в систему"))

    keys = Key.query.filter(Key.username == current_user).all()
    answer = RequestAnswer.query.filter(RequestAnswer.username == current_user).first()
    request_pending = Request.query.filter(Request.username == current_user).first()

    session['current_user_login'] = current_user
    return render_template('user_dashboard.html', keys=keys, answer=answer, request_pending=request_pending)


# ------------------------------------------------------------
# Удаление ключа пользователем
# ------------------------------------------------------------
@app.route('/delete_key', methods=['POST'])
def delete_key():
    error = None
    current_user = session.get('current_user_login')
    if not current_user:
        return redirect(url_for('login', error="Необходимо повторно войти в систему"))

    key_id = request.form.get('key_id')
    if not key_id:
        return redirect(url_for('user_dashboard', error="Ключ для удаления не найден"))

    key = Key.query.get(int(key_id))
    if key is None:
        return redirect(url_for('user_dashboard', error="Ключ не найден"))
    if key.username != current_user:
        return redirect(url_for('user_dashboard', error="Чужой ключ удалить нельзя"))

    delete_user_key(key_id)
    db.session.delete(key)
    db.session.commit()
    write_log(current_user, f"Удалён ключ {key.keyidentity}")
    return redirect(url_for('user_dashboard', error=error))


# ------------------------------------------------------------
# Запрос на получение ключей
# ------------------------------------------------------------
@app.route('/request_key', methods=['POST'])
def request_key():
    error = None
    current_user = session.get('current_user_login')
    if not current_user:
        return redirect(url_for('login', error="Необходимо повторно войти в систему"))

    key_amount = request.form.get("key_amount")
    keygroup_name = request.form.get("keygroup_name")
    description = request.form.get("description")

    # Удаляем старый запрос, если есть
    old_req = Request.query.filter(Request.username == current_user).first()
    if old_req:
        db.session.delete(old_req)
        db.session.commit()

    req = Request()
    req.set_username(current_user)
    req.set_quantity(key_amount)
    req.set_keygroup_name(keygroup_name)
    req.set_description(str(description))
    db.session.add(req)
    db.session.commit()

    write_log(current_user, f"Отправлен запрос на {key_amount} ключей, группа '{keygroup_name}'")
    return redirect(url_for('user_dashboard', error=error))


# ------------------------------------------------------------
# Панель администратора
# ------------------------------------------------------------
@app.route('/admin_dashboard', methods=['GET'])
def admin_dashboard():
    error = None
    current_admin = session.get('current_user_login')
    if not current_admin:
        return redirect(url_for('login', error="Необходимо повторно войти в систему"))

    admin_user = User.query.filter(User.username == current_admin).first()
    if admin_user is None or not admin_user.is_admin:
        return redirect(url_for('login', error="Недостаточно прав"))

    keys = Key.query.all()
    users = User.query.all()
    reqs = Request.query.all()
    logs = Log.query.order_by(Log.date.desc()).all()

    return render_template('admin_dashboard.html', users=users, reqs=reqs, keys=keys, logs=logs)


# ------------------------------------------------------------
# Удаление пользователя администратором
# ------------------------------------------------------------
@app.route('/admin_delete_user', methods=['POST'])
def admin_delete_user():
    error = None
    current_admin = session.get('current_user_login')
    user_id = request.form.get("user_id")
    user = User.query.filter(User.id == user_id).first()
    if user is None:
        return redirect(url_for('admin_dashboard', error="Пользователь не найден"))

    # Удаляем ключи пользователя
    user_keys = Key.query.filter(Key.username == user.username).all()
    for key in user_keys:
        delete_user_key(key.id)
        db.session.delete(key)

    # Удаляем запросы пользователя
    user_requests = Request.query.filter(Request.username == user.username).all()
    for req in user_requests:
        db.session.delete(req)

    # Удаляем ответы на запросы
    user_request_answers = RequestAnswer.query.filter(RequestAnswer.username == user.username).all()
    for ans in user_request_answers:
        db.session.delete(ans)

    db.session.delete(user)
    db.session.commit()

    write_log(current_admin, f"Удалён пользователь {user.username}")
    return redirect(url_for('admin_dashboard', error=error))


# ------------------------------------------------------------
# Удаление ключа администратором
# ------------------------------------------------------------
@app.route('/admin_delete_key', methods=['POST'])
def admin_delete_key():
    error = None
    current_admin = session.get('current_user_login')
    key_id = request.form.get('key_id')
    key = Key.query.filter(Key.id == key_id).first()
    if key is None:
        return redirect(url_for('admin_dashboard', error="Не удалось найти заданный ключ"))

    delete_user_key(key.id)
    db.session.delete(key)
    db.session.commit()

    write_log(current_admin, f"Удалён ключ {key.keyidentity}")
    return redirect(url_for('admin_dashboard', error=error))


# ------------------------------------------------------------
# Ответ на запрос пользователя
# ------------------------------------------------------------
@app.route('/admin_answer_request', methods=['POST'])
def admin_answer_request():
    error = None
    current_admin = session.get('current_user_login')

    req_id = request.form.get('req_id')
    keygroup_name = request.form.get('keygroup_name')
    answer_request = request.form.get('answer_request')
    answer_message = request.form.get('answer_message')
    username = request.form.get('username')

    req = Request.query.filter(Request.id == req_id).first()
    if req is None:
        return redirect(url_for('admin_dashboard', error="Не удалось найти соответствующий запрос"))

    # Подготавливаем ответ
    answer = RequestAnswer()
    old_answer = RequestAnswer.query.filter(RequestAnswer.username == username).first()
    if old_answer:
        db.session.delete(old_answer)
        db.session.commit()

    answer.set_username(username)
    answer.set_answer(answer_message if answer_message else "")

    if answer_request == "positive":
        # Создаём ключи
        for i in range(int(req.quantity)):
            keyname = f"{req.keygroup_name}{i}"
            resp = create_key(name=keyname)
            if resp != 1:
                new_key = Key()
                new_key.set_id(resp['id'])
                new_key.set_keyname_name(resp['name'])
                new_key.set_keyname(resp['accessUrl'])
                new_key.set_username(req.username)
                db.session.add(new_key)
            else:
                error = "Не удалось создать новый ключ"
                write_log(current_admin, f"Ошибка создания ключа для запроса от {req.username}")
                break
        else:
            # Если цикл завершился без break
            answer.set_verdict(True)
            write_log(current_admin, f"Одобрен запрос от {req.username} на {req.quantity} ключей")
        db.session.commit()
    else:
        answer.set_verdict(False)
        write_log(current_admin, f"Отклонён запрос от {req.username}")

    # Удаляем запрос и сохраняем ответ
    db.session.delete(req)
    db.session.add(answer)
    db.session.commit()

    return redirect(url_for('admin_dashboard', error=error))


# ------------------------------------------------------------
# Создание нового администратора
# ------------------------------------------------------------
@app.route('/create_new_admin', methods=['POST'])
def create_new_admin():
    error = None
    current_admin = session.get('current_user_login')
    username = request.form.get('username')
    email = request.form.get('email')
    password = request.form.get('password')
    password_repeat = request.form.get('password_repeat')

    existing_user = User.query.filter(User.username == username).first()
    if existing_user:
        # Повышаем права существующего пользователя
        existing_user.set_is_admin(True)
        db.session.commit()
        write_log(current_admin, f"Пользователю {username} выданы права администратора")
        return redirect(url_for('admin_dashboard', error=error))

    # Создаём нового администратора
    if password != password_repeat:
        error = "Пароли не совпали, попробуйте еще раз"
    elif not password or not password_repeat:
        error = "При создании нового пользователя с правами администратора необходимо ввести для него пароль"
    else:
        user = User()
        user.set_username(username)
        user.set_email(email)
        user.set_password(password)
        user.set_is_admin(True)
        user.set_is_confirmed(True)
        db.session.add(user)
        db.session.commit()
        write_log(current_admin, f"Создан новый администратор {username}")
        return redirect(url_for('admin_dashboard', error=error))

    # Если ошибка валидации
    write_log(current_admin, f"Ошибка при создании администратора: {error}")
    return redirect(url_for('admin_dashboard', error=error))


# ------------------------------------------------------------
# Точка входа
# ------------------------------------------------------------
if __name__ == "__main__":
    app.run(debug=True)
