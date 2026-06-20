from extensions import db
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)

    def set_username(self, username):
        self.username = username

    def set_email(self, email):
        self.email = email

    def set_status(self, status):
        if status:
            self.is_admin = True
        else:
            self.is_admin = False

    def get_username(self, username):
        return self.username

    def get_email(self, email):
        return self.email

    def get_status(self, status):
        return self.is_admin

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.username}>'
