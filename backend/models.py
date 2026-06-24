from extensions import db
from werkzeug.security import generate_password_hash, check_password_hash

class Key(db.Model):
    __tablename__ = 'keys'

    id = db.Column(db.Integer, primary_key=True)
    keyidentity = db.Column(db.String(64), unique=False, nullable=False)
    keyname = db.Column(db.String(128), unique=True, nullable=False, index=True)
    username = db.Column(db.String(64), unique=False, nullable=False)

    def set_keyname(self, keyname):
        self.keyname = keyname

    def set_username(self, username):
        self.username = username

    def set_keyname_name(self, keyname_name):
        self.keyidentity = keyname_name

    def get_id(self):
        return self.id

    def get_keyname(self):
        return self.keyname

    def get_keyname_name(self):
        return self.keyidentity

    def get_username(self):
        return self.username

    def __repr__(self):
        return f'<Key {self.keyname}>'


class Request(db.Model):
    __tablename__ = 'requests'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False, index=True)
    quantity = db.Column(db.Integer, unique=False, nullable=False)
    keygroup_name = db.Column(db.String(64), unique=True, nullable=False)
    description = db.Column(db.String(1024), unique=False, nullable=False)

    def set_quantity(self, quantity):
        self.quantity = quantity

    def set_description(self, description=""):
        self.description = description

    def set_username(self, username):
        self.username = username

    def set_id(self, id):
        self.id = id

    def set_keygroup_name(self, keygroup_name):
        self.keygroup_name = keygroup_name

    def get_quantity(self):
        return self.quantity

    def get_keygroup_name(self):
        return self.keygroup_name

    def get_description(self):
        return self.description

    def __repr__(self):
        return f'<Request {self.description}>'


class RequestAnswer(db.Model):
    __tablename__ = 'requestAnswers'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False, index=True)
    verdict = db.Column(db.Boolean, unique=False, nullable=False)
    answer = db.Column(db.String(1024), unique=False, nullable=False)

    def set_username(self, username):
        self.username = username

    def set_id(self, id):
        self.id = id

    def set_answer(self, answer=""):
        self.answer = answer

    def set_verdict(self, verdict=False):
        self.verdict = verdict

    def get_verdict(self):
        return self.verdict

    def get_id(self):
        return self.id

    def get_username(self):
        return self.username

    def get_answer(self):
        return self.answer

    def __repr__(self):
        return f'<RequestAnswer {self.answer}>'


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
