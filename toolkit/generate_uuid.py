import uuid
import hashlib

uuid_value = str(uuid.uuid4())

short_hash = hashlib.sha1(uuid_value.encode()).hexdigest()[:8]

print(short_hash)

