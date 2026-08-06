from pydantic import BaseModel, Field


class HomeContentCardRequest(BaseModel):
    scope: str | None = None
    title: str = Field(..., min_length=3, max_length=120)
    body: str = Field(..., min_length=5, max_length=800)
    image_url: str = Field(..., min_length=5, max_length=500)
    display_order: int = 0
    is_active: bool = True


class HomeContentCardResponse(BaseModel):
    id: int
    scope: str
    title: str
    body: str
    image_url: str
    display_order: int
    is_active: bool
