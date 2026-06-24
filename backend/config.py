import os

basedir = os.path.abspath(os.path.dirname(__file__))

def _load_env_file():
    """Читает envy.conf из корня проекта и возвращает словарь с настройками."""
    env_path = os.path.join(basedir, '..', 'envy.conf')
    config = {}
    if os.path.isfile(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                # Формат: ключ значение (первый пробел разделяет)
                parts = line.split(' ', 1)
                if len(parts) == 2:
                    config[parts[0]] = parts[1]
    return config

_env = _load_env_file()

class Config:
    # Секретный ключ Flask
    SECRET_KEY = os.environ.get('SECRET_KEY') or _env.get('secret_key') or 'запасной-ключ-для-разработки'

    # Подключение к PostgreSQL
    db_name = _env.get('db_name', 'default_db')
    db_username = _env.get('db_username', 'postgres')
    db_username_password = _env.get('db_username_password', '')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
        f"postgresql://{db_username}:{db_username_password}@127.0.0.1/{db_name}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Настройки почты
    email = _env.get('email', '')
    email_password = _env.get('email_password', '')
    MAIL_SERVER = 'smtp.gmail.com'
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USE_SSL = False
    MAIL_USERNAME = email
    MAIL_PASSWORD = email_password
    MAIL_DEFAULT_SENDER = ('Docent VPN', email)
    IS_MAIL_COOKED = bool(_env.get('is_mail_cooked', '1'))
