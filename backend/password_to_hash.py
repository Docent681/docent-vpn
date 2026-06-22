from werkzeug.security import generate_password_hash, check_password_hash
from sys import stdin, stdout

password = stdin.readline().strip()
hash = generate_password_hash(password)
stdout.write(hash)
