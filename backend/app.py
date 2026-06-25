from flask import Flask, redirect, render_template, url_for, request, session
from flask_mailman import EmailMessage
from sqlalchemy.orm import query
from services import code_generate, create_key, delete_user_key
from config import Config
from extensions import db, migrate, mail

app = Flask(__name__)
app.config.from_object(Config)

db.init_app(app)
mail.init_app(app)
migrate.init_app(app, db)
from models import RequestAnswer, User, Request, Key

#Действия при прямом входе по URL
@app.route('/')
def index():
    return redirect(url_for('login'))

#Страница для регистрации нового пользователя
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
        elif User.query.filter((User.username==username) & (User.is_confirmed==True)).first() is not None:
            error = "Пользователь под данным логином уже существует в системе"
        elif User.query.filter((User.email==email) & (User.is_confirmed==True)).first() is not None:
            error = "Пользователь под данной почтой уже существует в системе"
        else:
            user = User.query.filter(((User.username==username) & (User.is_confirmed==False)) | ((User.email==email) & (User.is_confirmed==False))).first()
            if user is None:
                user = User()
            user.set_username(username)
            user.set_email(email)
            user.set_password(password)
            user.set_is_admin(False)
            user.set_is_confirmed(True)
            #user.set_is_confirmed(False)
            db.session.add(user)
            db.session.commit()

            if Config.IS_MAIL_COOKED:
                return redirect(url_for('login', error=error))
            else:
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

    return render_template('register.html', error=error)

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
                session.clear()
                return redirect(url_for('login', error=error))
            else:
                error = "Произошла ошибка. Попробуйте зарегистрироваться еще раз"
                db.session.delete(user)
                db.session.commit()
                session.clear()
                return redirect(url_for('register', error=error))
        else:
            error = "Вы неверно ввели код подтверждение. Попробуйте зарегестрироваться заново"
            db.session.delete(user)
            db.session.commit()
            session.clear()
            return redirect(url_for('register', error=error))

    return render_template('verify.html', error=error)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

#Страница для входа пользователя/администратора
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
        else:
            session.clear()
            session['current_user_login'] = username

            if user_type == 'user_choice':
                return redirect(url_for('user_dashboard', error=error))
            return redirect(url_for("admin_dashboard", error=error))

    return render_template('login.html', error=error)

#Основная страница пользователя
@app.route('/user_dashboard', methods=['GET'])
def user_dashboard():
    error = None
    current_user = session.get('current_user_login')
    if not current_user:
        error = "Необходимо войти в систему"
        return redirect(url_for('login', error=error))
    keys = Key.query.filter(Key.username == current_user).all()
    answer = RequestAnswer.query.filter(RequestAnswer.username == current_user).first()
    if Request.query.filter(Request.username == current_user).first is not None:
        request_pending = True
    else:
        request_pending = False

    session['current_user_login'] = current_user
    return render_template('user_dashboard.html', keys=keys, answer=answer, request_pending=request_pending)

@app.route('/delete_key', methods=['POST'])
def delete_key():
    error=None
    current_user = session.get('current_user_login')
    if not current_user:
        error = "Необходимо повторно войти в систему"
        return redirect(url_for('login', error=error))

    key_id = request.form.get('key_id')
    if not key_id:
        error = "Ключ для удаления не был найден"
        return redirect(url_for('user_dashboard', error=error))
    key = Key.query.get(int(key_id))
    if key is None:
        pass
    else:
        if key.username != current_user:
            pass
        else:
            delete_user_key(key_id)
            db.session.delete(key)
            db.session.commit()

    return redirect(url_for('user_dashboard', error=error))

@app.route('/request_key', methods=['POST'])
def request_key():
    error = None
    current_user = session.get('current_user_login')
    if not current_user:
        error = "Необходимо повторно войти в систему"
        return redirect(url_for('login', error=error))

    key_amount = request.form.get("key_amount")
    keygroup_name = request.form.get("keygroup_name")
    description = request.form.get("description")

    if Request.query.filter(Request.username == current_user).first() is None:
        pass
    else:
        old_req = Request.query.filter(Request.username == current_user).first()
        db.session.delete(old_req)
        db.session.commit()
    req = Request()
    req.set_username(current_user)
    req.set_quantity(key_amount)
    req.set_keygroup_name(keygroup_name)
    req.set_description(str(description))
    db.session.add(req)
    db.session.commit()

    return redirect(url_for('user_dashboard', error=error))

#Основная страница администратора
@app.route('/admin_dashboard', methods=['GET'])
def admin_dashboard():
    error = None
    current_admin = session.get('current_user_login')
    if not current_admin:
        error = "Необходимо повторно войти в систему"
        return redirect(url_for('login', error=error))
    keys = Key.query.all()
    users = User.query.all()
    reqs = Request.query.all()

    return render_template('admin_dashboard.html', users=users, reqs=reqs, keys=keys )

@app.route('/admin_delete_user', methods=['POST'])
def admin_delete_user():
    error = None
    user_id = request.form.get("user_id")
    user = User.query.filter(User.id == user_id).first()
    if user is None:
        error = "Пользователь не найден в системе"
    else:
        user_keys = Key.query.filter(Key.username == user.username).all()
        for key in user_keys:
            delete_user_key(key.id)
            db.session.delete(key)
            db.session.delete(user)
            db.session.commit()
        else:
            error = "Пользователь не был удален, так как не получилось удалить чать ключей"

    return redirect(url_for('admin_dashboard', error=error))

@app.route('/admin_delete_key', methods=['POST'])
def admin_delete_key():
    error = None

    key_id = request.form.get('key_id')
    if Key.query.filter(Key.id == key_id).first() is not None:
        key = Key.query.filter(Key.id == key_id).first()
        delete_user_key(id)
        db.session.delete(key)
        db.session.commit()
    else:
        error = "Не удалось найти заданный ключ"

    return redirect(url_for('admin_dashboard', error=error))

@app.route('/admin_answer_request', methods=['POST'])
def admin_answer_request():
    error = None

    req_id = request.form.get('req_id')
    keygroup_name = request.form.get('keygroup_name')
    answer_request = request.form.get('answer_request')
    answer_message = request.form.get('answer_message')
    username = request.form.get('username')

    req = Request.query.filter(Request.id == req_id ).first()
    if req is not None:

        answer = RequestAnswer()
        if RequestAnswer.query.filter(RequestAnswer.username == username).first() is not None:
            old_answer = RequestAnswer.query.filter(RequestAnswer.username == username).first()
            db.session.delete(old_answer)
            db.session.commit()

        answer.set_username(username)

        if answer_message is None:
            answer.set_answer("")
        else:
            answer.set_answer(answer_message)

        if answer_request == "positive":
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
                    db.session.commit()
                else:
                    error = "Не удалось создать новый ключ"
            answer.set_verdict(True)
        else:
            answer.set_verdict(False)

        db.session.delete(req)
        db.session.add(answer)
        db.session.commit()
    else:
        error = "Не удалось найти соответсвующий запрос"

    return redirect(url_for('admin_dashboard', error=error))

@app.route('/create_new_admin', methods=['POST'])
def create_new_admin():
    error = None
    username = request.form.get('username')
    email = request.form.get('email')
    password = request.form.get('password')
    password_repeat = request.form.get('password_repeat')

    if User.query.filter(User.username == username).first() is not None:
        user = User.query.filter(User.username == username).first()
        if user is not None:
            user.set_set_is_admin(True)
    else:
        if password != password_repeat:
            error = "Пароли не совпали, попробуйте еще раз"
        elif password == None or password_repeat == None:
            error = "При создании нового пользователя с правами администратора необходимо ввести для него пароль"
        user = User()
        user.set_username(username)
        user.set_email(email)
        user.set_password(password)
        user.set_is_admin(True)
        user.set_is_confirmed(True)
    db.session.add(user)
    db.session.commit()
    return redirect(url_for('admin_dashboard', error=error))


if __name__ == "__main__":
    app.run(debug=True)
