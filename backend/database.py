from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base

# This is the correct line for a simple, local SQLite database.
# It will create a file named 'test.db' in your project folder.
SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

# We add echo=True for local development so we can see the SQL commands in the terminal.
engine = create_async_engine(SQLALCHEMY_DATABASE_URL, echo=True)

# The rest of the file defines how to talk to the database.
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
Base = declarative_base()

# В файле database.py

# from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
# from sqlalchemy.orm import declarative_base

SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

engine = create_async_engine(SQLALCHEMY_DATABASE_URL, echo=True)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
Base = declarative_base()

# --- ДОБАВЬТЕ ЭТУ ФУНКЦИЮ В КОНЕЦ ФАЙЛА ---
# Эта функция будет нашим единым источником сессий БД для всего приложения
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session