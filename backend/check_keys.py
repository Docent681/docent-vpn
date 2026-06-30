from services import get_keys
from models import Key
from extensions import db
from time import sleep
from app import app

def main():
    keys = get_keys()
    if keys == 1:
        return 1
    for key in keys:
        if Key.query.filter(Key.keyidentity == key[0]).first() is None:
            new_key = Key()
            new_key.keyidentity = key[0]
            new_key.keyname = key[1]
            new_key.username = "OutlineManager"
            db.session.add(new_key)

            db.session.commit()

if __name__ == '__main__':
    with app.app_context():
        while True:
            main()
            sleep(900)
