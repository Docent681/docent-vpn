from flask import Flask, redirect, render_template, url_for, request
from config import Config
from extensions import db, migrate

app = Flask(__name__)
app.config.from_object(Config)

db.init_app(app)
migrate.init_app(app, db)
from models import User

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
        elif User.query.filter_by(username=username).first() is not None:
            error = "Пользователь под данным логином уже существует в системе"
        else:
            user = User()
            user.set_username(username)
            user.set_email(email)
            user.set_password(password)
            user.set_status(False)

            db.session.add(user)
            db.session.commit()
            #Здесь еще будет верификация по почте
            return redirect(url_for('login'))
    return render_template('register.html', error=error)

#Страница для входа пользователя/администратора
@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        user_type = request.form.get('user_type')

        user = User.query.filter_by(username=username).first()
        if user is None or not user.check_password(password):
            error = "Неверный логин или пароль"
        elif user_type == 'admin_choice' and not user.is_admin:
            error = "У вас нет прав администратора"
        else:
            if user_type == 'user_choice':
                return redirect(url_for('user_dashboard'))
            return redirect(url_for("admin_dashboard"))

    return render_template('login.html', error=error)

#Основная страница пользователя
@app.route('/user_dashboard')
def user_dashboard():
    return "Здесь будет меню для пользователя"

#Основная страница администратора
@app.route('/admin_dashboard')
def admin_dashboard():
    return "Здесь будет меню для администратора"


if __name__ == "__main__":
    app.run(debug=True)
