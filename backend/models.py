from extensions import db
from werkzeug.security import generate_password_hash, check_password_hash

class Key(db.Model):
    __tablename__ = 'keys'

    id = db.Column(db.Integer, primary_key=True)
    keyname = db.Column(db.String(64), unique=True, nullable=False, index=True)
    username = db.Column(db.String(64), unique=False, nullable=False)

    def set_keyname(self, keyname):
        self.keyname = keyname

    def set_username(self, username):
        self.username = username

    def get_id(self):
        return self.id

    def get_keyname(self):
        return self.keyname

    def get_username(self):
        return self.username

    def __repr__(self):
        return f'<Key {self.keyname}>'

class Request(db.Model):
    __tablename__ = 'requests'

    id = db.Column(db.Integer, primary_key=True)
    quantity = db.Column(db.Integer, unique=False, nullable=False)
    description = db.Column(db.String(1024), unique=False, nullable=True)

    def set_quantity(self, quantity):
        self.quantity = quantity

    def set_description(self, description=""):
        self.description = description

    def get_quantity(self):
        return self.quantity

    def get_description(self):
        return self.description

    def __repr__(self):
        return f'<Request {self.description}>'

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    is_confirmed = db.Column(db.Boolean, default=False)

    def set_username(self, username):
        self.username = username

    def set_email(self, email):
        self.email = email

    def set_is_admin(self, status):
        if status:
            self.is_admin = True
        else:
            self.is_admin = False

    def set_is_confirmed(self, status):
        if status:
            self.is_confirmed= True
        else:
            self.is_confirmed= False


    def get_username(self):
        return self.username

    def get_id(self):
        return self.id

    def get_email(self):
        return self.email

    def get_is_admin(self):
        return self.is_admin

    def get_is_confirmed(self):
        return self.is_confirmed

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.username}>'
