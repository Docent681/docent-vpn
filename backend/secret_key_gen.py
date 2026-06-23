import random
import string
from sys import stdin, stdout

characters = string.ascii_letters + string.digits
res = ''.join(random.choices(characters, k=32))
stdout.write(res)
