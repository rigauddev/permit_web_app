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
    approval_status: str
    owner_name: str | None = None


class ServiceConfigRequest(BaseModel):
    is_active: bool


class ServiceConfigResponse(BaseModel):
    key: str
    title: str
    description: str | None = None
    is_active: bool


class BannerApprovalRequest(BaseModel):
    approved: bool


class ContentSettingsRequest(BaseModel):
    event_map_title: str = Field(..., min_length=3, max_length=120)
    event_map_description: str = Field(..., min_length=5, max_length=500)
    event_map_editor_secretarias: list[str] = Field(default_factory=list)


class ContentSettingsResponse(ContentSettingsRequest):
    can_edit_event_map: bool = False
    can_manage_editors: bool = False


class TourismPointRequest(BaseModel):
    title: str = Field(..., min_length=2, max_length=120)
    detail: str = Field(..., min_length=2, max_length=255)
    place: str = Field(..., min_length=2, max_length=255)
    category: str = Field(..., min_length=2, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    marker_x: float = Field(default=0.5, ge=0, le=1)
    marker_y: float = Field(default=0.5, ge=0, le=1)
    display_order: int = 0
    is_active: bool = True


class TourismPointResponse(TourismPointRequest):
    id: int
