import uuid
from fastapi import APIRouter, Depends, Header, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import require_roles
from app.core.database import get_db
from app.schemas.auth import CurrentUserDTO
from app.schemas.order import (
    OrderCreateDTO,
    OrderDTO,
    PaymentRequestDTO,
    PaymentResultDTO,
    RefundRequestDTO,
    RefundResponseDTO,
)
from app.services.order_service import OrderService

router = APIRouter(prefix="/orders", tags=["Customer Orders & Ticketing"])
customer_guard = require_roles("CUSTOMER", "CINEMA_ADMIN", "PLATFORM_ADMIN")


@router.post("", response_model=OrderDTO, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreateDTO,
    idempotency_key: str = Header(..., alias="Idempotency-Key", min_length=1, max_length=128),
    actor: CurrentUserDTO = Depends(customer_guard),
    db: AsyncSession = Depends(get_db),
) -> OrderDTO:
    return await OrderService(db).create_order(payload, idempotency_key, actor)


@router.get("", response_model=list[OrderDTO])
async def list_my_orders(
    actor: CurrentUserDTO = Depends(customer_guard),
    db: AsyncSession = Depends(get_db),
) -> list[OrderDTO]:
    return await OrderService(db).list_my_orders(actor)


@router.get("/{order_id}", response_model=OrderDTO)
async def get_my_order(
    order_id: uuid.UUID,
    actor: CurrentUserDTO = Depends(customer_guard),
    db: AsyncSession = Depends(get_db),
) -> OrderDTO:
    return await OrderService(db).get_my_order(order_id, actor)


@router.post("/{order_id}/pay", response_model=PaymentResultDTO)
async def pay_order(
    order_id: uuid.UUID,
    payload: PaymentRequestDTO,
    response: Response,
    idempotency_key: str = Header(..., alias="Idempotency-Key", min_length=1, max_length=128),
    actor: CurrentUserDTO = Depends(customer_guard),
    db: AsyncSession = Depends(get_db),
) -> PaymentResultDTO:
    http_code, result = await OrderService(db).pay_order(order_id, payload, idempotency_key, actor)
    response.status_code = http_code
    return result


@router.post("/{order_id}/refund", response_model=RefundResponseDTO)
async def refund_order(
    order_id: uuid.UUID,
    payload: RefundRequestDTO,
    actor: CurrentUserDTO = Depends(customer_guard),
    db: AsyncSession = Depends(get_db),
) -> RefundResponseDTO:
    return await OrderService(db).refund_order(order_id, payload, actor)
