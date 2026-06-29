from services import get_keys
from models import Key
from extensions import db
from time import sleep

keys = get_keys()
for key in keys:
    if Key.query.filter(Key.keyidentity == key[0]).first() is None:
        new_key = Key()
        new_key.keyidentity = key[0]
        new_key.keyname = key[1]
        new_key.username = "OutlineManager"
        db.session.add(new_key)

db.session.commit()
sleep(900)
