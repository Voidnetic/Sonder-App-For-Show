import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.user import UserResponse

ReportTarget = Literal["user", "memory", "message"]
ReportReason = Literal["spam", "harassment", "nudity", "violence", "hate", "self_harm", "impersonation", "other"]


class BlockRequest(BaseModel):
    user_id: uuid.UUID


class CreateReportRequest(BaseModel):
    target_type: ReportTarget
    target_id: uuid.UUID
    reason: ReportReason
    details: str | None = Field(default=None, max_length=1000)
    # Also block the person who posted it, in the same step.
    block: bool = False


class ReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    target_type: ReportTarget
    target_id: uuid.UUID
    reason: str
    status: str
    created_at: datetime


class AdminReportResponse(ReportResponse):
    details: str | None
    reporter: UserResponse | None
    reported_user: UserResponse | None
    # A short description of what was reported: the message text or the photo's address.
    preview: str | None


class ResolveReportRequest(BaseModel):
    action: Literal["dismiss", "remove_content", "delete_user"]
