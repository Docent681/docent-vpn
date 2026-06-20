from flask import Flask, redirect, render_template, url_for, request

app = Flask(__name__)

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        password_repeat = request.form.get('password_repeat')
        if password == password_repeat:
            return f"Привет, {username}! Вы зарегистрировались с почтой {email}"

    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        user_type = request.form.get('user_type')
        return f"Привет, {username}! Вы вошли как {user_type}"

    return render_template('login.html')

if __name__ == "__main__":
    app.run(debug=True)
