"""
User service module supplying registration, login, and image tracking helpers.

This module centralizes all lightweight persistence needs for the sample
authentication flow so the Flask server does not have to deal with SQLite
bookkeeping directly.
"""
from __future__ import annotations

import os
import sqlite3
import uuid
from datetime import datetime
from typing import List, Optional

from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename


class UserService:
    """
    Simple facade around SQLite that manages users and their uploaded images.

    Usage:
        >>> service = UserService()
        >>> service.register_user(username="demo", password="secret123")
        >>> token = service.login_user(username="demo", password="secret123")
        >>> service.save_user_image(
        ...     user_token=token,
        ...     file_bytes=b"fake bytes for docs",
        ...     original_filename="avatar.png",
        ... )

    The class automatically creates all required folders and database tables
    on first use, which makes it ideal for demos and local development.
    """

    def __init__(
        self,
        db_path: str = "/Volumes/Development/projects/Python/remove_bg_image/data/users.db",
        user_upload_root: str = "/Volumes/Development/projects/Python/remove_bg_image/uploads/user_uploads",
    ) -> None:
        """
        Initialize the service with configurable paths for storage.

        Example:
            >>> UserService(
            ...     db_path="/tmp/app/users.db",
            ...     user_upload_root="/tmp/app/uploads",
            ... )

        Args:
            db_path: Absolute path to the SQLite database file.
            user_upload_root: Directory where per-user folders will be created.
        """
        self.db_path = db_path
        self.user_upload_root = user_upload_root

        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        os.makedirs(self.user_upload_root, exist_ok=True)
        self._initialize_database()

    def _get_connection(self) -> sqlite3.Connection:
        """
        Create a new SQLite connection so every request stays isolated.

        Example:
            >>> with service._get_connection() as conn:
            ...     conn.execute("SELECT 1")
        """
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _initialize_database(self) -> None:
        """
        Create tables needed for users and their images if they do not exist.

        This keeps setup zero-config. The routine can safely run multiple times.
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    auth_token TEXT,
                    created_at TEXT NOT NULL
                );
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS user_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    original_filename TEXT NOT NULL,
                    stored_path TEXT NOT NULL,
                    uploaded_at TEXT NOT NULL,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                );
                """
            )
            conn.commit()

    def register_user(self, username: str, password: str) -> bool:
        """
        Register a user with a hashed password.

        Returns:
            bool indicating whether the user was created (False if duplicate).

        Example:
            >>> service.register_user("alex", "StrongPass!23")
            True
        """
        normalized_username = username.strip().lower()
        if not normalized_username:
            return False

        password_hash = generate_password_hash(password)
        try:
            with self._get_connection() as conn:
                conn.execute(
                    """
                    INSERT INTO users (username, password_hash, created_at)
                    VALUES (?, ?, ?);
                    """,
                    (normalized_username, password_hash, datetime.utcnow().isoformat()),
                )
                conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False

    def login_user(self, username: str, password: str) -> Optional[str]:
        """
        Verify credentials and return a fresh auth token.

        Example:
            >>> token = service.login_user("alex", "StrongPass!23")
            >>> print(token)
            "8230a4b1..."  # token string
        """
        normalized_username = username.strip().lower()
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT id, password_hash FROM users WHERE username = ?;",
                (normalized_username,),
            )
            row = cursor.fetchone()

            if not row or not check_password_hash(row["password_hash"], password):
                return None

            token = uuid.uuid4().hex
            conn.execute(
                "UPDATE users SET auth_token = ? WHERE id = ?;",
                (token, row["id"]),
            )
            conn.commit()
            return token

    def get_user_by_token(self, token: str) -> Optional[sqlite3.Row]:
        """
        Locate a user row via their auth token to authorize requests.

        Example:
            >>> user = service.get_user_by_token(token="8230a4b1")
            >>> user["username"]
            "alex"
        """
        if not token:
            return None

        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT id, username FROM users WHERE auth_token = ?;",
                (token,),
            )
            return cursor.fetchone()

    def save_user_image(self, user_id: int, username: str, file_storage) -> Optional[str]:
        """
        Persist the uploaded image and link it to the user.

        Args:
            user_id: Database identifier for the user.
            username: Username for folder naming.
            file_storage: Werkzeug FileStorage coming from Flask.

        Returns:
            Stored path relative to the repository root or None on failure.

        Example:
            >>> service.save_user_image(
            ...     user_id=1,
            ...     username="alex",
            ...     file_storage=request.files["image"],
            ... )
        """
        if not file_storage or file_storage.filename == "":
            return None

        safe_filename = secure_filename(file_storage.filename)
        timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")
        user_folder = os.path.join(self.user_upload_root, username)
        os.makedirs(user_folder, exist_ok=True)

        stored_filename = f"{timestamp}_{safe_filename}"
        stored_path = os.path.join(user_folder, stored_filename)
        file_storage.save(stored_path)

        relative_path = os.path.relpath(
            stored_path,
            start="/Volumes/Development/projects/Python/remove_bg_image",
        )

        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO user_images (
                    user_id,
                    original_filename,
                    stored_path,
                    uploaded_at
                )
                VALUES (?, ?, ?, ?);
                """,
                (
                    user_id,
                    safe_filename,
                    relative_path,
                    datetime.utcnow().isoformat(),
                ),
            )
            conn.commit()

        return relative_path

    def list_user_images(self, user_id: int) -> List[dict]:
        """
        Return metadata for all images that belong to the user.

        Example:
            >>> service.list_user_images(user_id=1)
            [
                {"original_filename": "photo.png", "stored_path": "uploads/..."},
                ...
            ]
        """
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT original_filename, stored_path, uploaded_at
                FROM user_images
                WHERE user_id = ?
                ORDER BY uploaded_at DESC;
                """,
                (user_id,),
            )
            rows = cursor.fetchall()

        return [
            {
                "original_filename": row["original_filename"],
                "stored_path": row["stored_path"],
                "uploaded_at": row["uploaded_at"],
            }
            for row in rows
        ]

