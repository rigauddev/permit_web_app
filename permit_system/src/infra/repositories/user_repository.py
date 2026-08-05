from sqlalchemy.orm import Session
from src.infra.database.models import UserModel
from src.entities.user_entity import UserEntity

class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_user_by_email(self, email: str):
        db_user = self.db.query(UserModel).filter(UserModel.email == email).first()
        if db_user:
            return UserEntity(**db_user.__dict__)
        return None

    def create_user(self, user: UserEntity):
        db_user = UserModel(**user.dict())
        self.db.add(db_user)
        self.db.commit()
        self.db.refresh(db_user)
        return UserEntity(**db_user.__dict__)