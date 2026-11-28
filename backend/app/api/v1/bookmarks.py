import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.auth import CurrentUserDTO
from app.schemas.catalog import BookmarkToggleResponseDTO, MovieDTO, RecommendedMoviesResponseDTO
from app.services.bookmark_service import BookmarkService

router = APIRouter(tags=["Bookmarks & Recommendations"])


@router.get("/bookmarks", response_model=list[MovieDTO])
async def list_bookmarks(
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MovieDTO]:
    return await BookmarkService(db).list_bookmarked_movies(current_user.id)


@router.post("/bookmarks/{movie_id}", response_model=BookmarkToggleResponseDTO)
async def add_bookmark(
    movie_id: uuid.UUID,
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BookmarkToggleResponseDTO:
    return await BookmarkService(db).add_bookmark(current_user.id, movie_id)


@router.delete("/bookmarks/{movie_id}", response_model=BookmarkToggleResponseDTO)
async def remove_bookmark(
    movie_id: uuid.UUID,
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BookmarkToggleResponseDTO:
    return await BookmarkService(db).remove_bookmark(current_user.id, movie_id)


@router.get("/recommendations", response_model=RecommendedMoviesResponseDTO)
async def get_recommendations(
    current_user: CurrentUserDTO = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RecommendedMoviesResponseDTO:
    return await BookmarkService(db).get_recommendations(current_user.id)
