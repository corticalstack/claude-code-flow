# Async Programming Patterns

## Entry Point

```python
import asyncio

async def main() -> None:
    result = await fetch_data("https://api.example.com")
    print(result)

if __name__ == "__main__":
    asyncio.run(main())  # Only correct entry point — never use get_event_loop().run_until_complete()
```

## Structured Concurrency with TaskGroup (Preferred)

`TaskGroup` is the correct way to run concurrent tasks. It guarantees all tasks finish or are cancelled when the block exits, and propagates all failures via `ExceptionGroup`.

```python
from asyncio import TaskGroup

# Run concurrent tasks — all results available after the block
async def fetch_all(urls: list[str]) -> list[dict[str, str]]:
    async with TaskGroup() as tg:
        tasks = [tg.create_task(fetch_data(url), name=f"fetch-{url}") for url in urls]
    # All tasks complete before this line; any exception cancels the rest
    return [task.result() for task in tasks]

# Handle multiple failure types with except*
async def robust_fetch(urls: list[str]) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    try:
        async with TaskGroup() as tg:
            tasks = [tg.create_task(fetch_data(url)) for url in urls]
    except* ValueError as eg:
        for exc in eg.exceptions:
            print(f"Bad URL: {exc}")
    except* ConnectionError as eg:
        for exc in eg.exceptions:
            print(f"Network error: {exc}")
    else:
        results = [t.result() for t in tasks]
    return results

# Process a batch
async def process_batch(items: list[int]) -> list[int]:
    async with TaskGroup() as tg:
        tasks = [tg.create_task(process_item(item)) for item in items]
    return [task.result() for task in tasks]
```

## asyncio.gather() — Legacy Pattern

```python
# ⚠️ asyncio.gather() is still valid but inferior to TaskGroup for structured concurrency.
# Use TaskGroup for new code. Use gather() only when you need return_exceptions=True
# semantics and genuinely want to suppress failures per-item.

# gather with error suppression (one valid use)
async def safe_fetch_all(urls: list[str]) -> list[dict[str, str] | None]:
    tasks = [fetch_data(url) for url in urls]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return [r if not isinstance(r, Exception) else None for r in results]
```

## Timeouts

```python
# asyncio.timeout() — use this (Python 3.11+)
async def fetch_with_timeout(url: str, timeout: float) -> dict[str, Any]:
    try:
        async with asyncio.timeout(timeout):
            return await fetch_data(url)
    except TimeoutError:
        return {"error": "timeout"}

# Combining timeout with TaskGroup
async def fetch_all_with_timeout(urls: list[str], timeout: float) -> list[dict[str, Any]]:
    async with asyncio.timeout(timeout):
        async with TaskGroup() as tg:
            tasks = [tg.create_task(fetch_data(url)) for url in urls]
    return [t.result() for t in tasks]

# ❌ asyncio.wait_for() is superseded — avoid in new code
# result = await asyncio.wait_for(coro(), timeout=5.0)  ❌
```

## Async Context Managers

```python
from typing import Self, Any
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

class AsyncDatabaseConnection:
    def __init__(self, url: str) -> None:
        self.url = url
        self._conn: Connection | None = None

    async def __aenter__(self) -> Self:
        self._conn = await connect(self.url)
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: Any,
    ) -> None:
        if self._conn:
            await self._conn.close()

    async def query(self, sql: str) -> list[dict[str, Any]]:
        if not self._conn:
            raise RuntimeError("Not connected")
        return await self._conn.execute(sql)

# asynccontextmanager — prefer this over __aenter__/__aexit__ for simple cases
@asynccontextmanager
async def get_db_session() -> AsyncIterator[Session]:
    session = await create_session()
    try:
        yield session
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    finally:
        await session.close()
```

## Async Generators

```python
from collections.abc import AsyncIterator

# Async generator for streaming data
async def read_lines(filepath: str) -> AsyncIterator[str]:
    async with aiofiles.open(filepath) as f:
        async for line in f:
            yield line.strip()

async def process_file(filepath: str) -> int:
    count = 0
    async for line in read_lines(filepath):
        await process_line(line)
        count += 1
    return count

# Paginated API streaming
async def fetch_paginated(url: str) -> AsyncIterator[dict[str, Any]]:
    page = 1
    async with httpx.AsyncClient() as client:
        while True:
            resp = await client.get(url, params={"page": page})
            data = resp.json()
            if not data:
                break
            yield data
            page += 1
```

## Async Comprehensions

```python
async def fetch_all_users(user_ids: list[int]) -> list[User]:
    return [user async for user in fetch_users(user_ids)]

async def build_user_map(user_ids: list[int]) -> dict[int, User]:
    return {user.id: user async for user in fetch_users(user_ids)}

async def get_active_users(user_ids: list[int]) -> list[User]:
    return [user async for user in fetch_users(user_ids) if user.is_active]
```

## Synchronization Primitives

```python
import asyncio

# Lock for critical sections
class SharedResource:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._data: dict[str, Any] = {}

    async def update(self, key: str, value: Any) -> None:
        async with self._lock:
            current = self._data.get(key, 0)
            await asyncio.sleep(0.1)
            self._data[key] = current + value

# Semaphore for rate limiting / bounded concurrency
class RateLimiter:
    def __init__(self, max_concurrent: int) -> None:
        self._semaphore = asyncio.Semaphore(max_concurrent)

    async def process(self, item: str) -> str:
        async with self._semaphore:
            return await expensive_operation(item)

# Event for coordination
class AsyncWorker:
    def __init__(self) -> None:
        self._ready = asyncio.Event()
        self._shutdown = asyncio.Event()

    async def start(self) -> None:
        await self._initialize()
        self._ready.set()
        await self._shutdown.wait()

    async def wait_ready(self) -> None:
        await self._ready.wait()

    def stop(self) -> None:
        self._shutdown.set()
```

## Producer-Consumer with Queue

```python
from asyncio import Queue, TaskGroup

async def producer(queue: Queue[int], n: int) -> None:
    for i in range(n):
        await queue.put(i)
        await asyncio.sleep(0.1)
    # Signal consumers to stop
    for _ in range(NUM_WORKERS):
        await queue.put(-1)

async def consumer(queue: Queue[int], name: str) -> None:
    while True:
        item = await queue.get()
        if item == -1:
            queue.task_done()
            break
        try:
            await process_item(item)
        finally:
            queue.task_done()

async def run_pipeline(num_items: int, num_workers: int) -> None:
    queue: Queue[int] = Queue(maxsize=10)
    async with TaskGroup() as tg:
        tg.create_task(producer(queue, num_items))
        for i in range(num_workers):
            tg.create_task(consumer(queue, f"worker-{i}"))
    await queue.join()
```

## Background Tasks

```python
from asyncio import create_task, Task
from collections.abc import Coroutine

class BackgroundTaskManager:
    def __init__(self) -> None:
        self._tasks: set[Task[None]] = set()

    def spawn(self, coro: Coroutine[None, None, None], *, name: str | None = None) -> Task[None]:
        task = create_task(coro, name=name)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)
        return task

    async def shutdown(self) -> None:
        for task in self._tasks:
            task.cancel()
        await asyncio.gather(*self._tasks, return_exceptions=True)
```

## Mixing Sync and Async

```python
import asyncio
import functools
from collections.abc import Callable

# Run blocking sync code in a thread executor (don't block the event loop)
async def run_blocking[T](func: Callable[..., T], *args: object) -> T:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, func, *args)

# Wrap a sync function to be async-safe
def to_async[T](func: Callable[..., T]) -> Callable[..., asyncio.coroutines]:
    @functools.wraps(func)
    async def wrapper(*args: object, **kwargs: object) -> T:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, functools.partial(func, *args, **kwargs))
    return wrapper
```

## Deprecations to Avoid

```python
# ❌ Deprecated — removal in Python 3.16
asyncio.set_event_loop_policy(...)      # use loop_factory= in asyncio.run() instead
asyncio.get_event_loop()                # use asyncio.get_running_loop() inside async code
asyncio.iscoroutinefunction(f)          # use inspect.iscoroutinefunction(f)

# ❌ Superseded
await asyncio.wait_for(coro(), timeout=5)  # use: async with asyncio.timeout(5):

# ✅ Replacements
asyncio.run(main(), loop_factory=asyncio.SelectorEventLoop)  # if custom loop needed
loop = asyncio.get_running_loop()       # inside async functions
import inspect; inspect.iscoroutinefunction(f)
```
