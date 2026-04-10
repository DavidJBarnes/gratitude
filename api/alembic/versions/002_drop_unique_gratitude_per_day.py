"""Drop unique constraint on gratitude per user per day

Revision ID: 002
Revises: 001
Create Date: 2026-04-10

"""
from typing import Sequence, Union

from alembic import op

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint("uq_gratitudes_user_date", "gratitudes", type_="unique")


def downgrade() -> None:
    op.create_unique_constraint("uq_gratitudes_user_date", "gratitudes", ["user_id", "entry_date"])
