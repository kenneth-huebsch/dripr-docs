# Queue Architecture Refactor Plan

## Overview
Transform the system from polling-based to event-driven queue architecture using Redis. This enables horizontal scaling, centralized rate limiting across workers, simplified status tracking, and robust fault tolerance.

## Architecture Changes

### Core Components
1. **Redis Queue System**: Task distribution via Redis lists (LPUSH/BRPOP)
2. **Centralized Rate Limiter**: Token bucket algorithm in Redis for all external APIs
3. **Simplified Status Model**: `campaign_status` + `processing_stage` instead of 6+ status fields
4. **Task Producers**: Services that enqueue work when campaigns are ready
5. **Task Consumers**: Horizontally-scalable workers that process tasks respecting rate limits

### Migration Approach
- Start with `data_fetcher` service first
- Then migrate `email_manager` 
- Keep existing status fields during migration for backward compatibility
- Use feature flags to switch between old/new systems

## Key Technical Decisions

### Queue Design
- **Separate queues per task type**: `property_data`, `active_listings`, `recent_sales`, `market_data`, `home_analysis`, `email_creation`, `email_sending`
- **Task payload**: `{campaign_id, task_type, retry_count, enqueued_at}`
- **Dead letter queue**: Failed tasks after max retries go to `failed_tasks` queue

### Rate Limiting
- **Redis keys**: `ratelimit:{api_name}:tokens` (current tokens), `ratelimit:{api_name}:last_refill` (timestamp)
- **Token bucket per API**: Zillow (10/min), RentCast (1/sec), Bedrock (8/min), EmailVerification (1/sec)
- **Atomic operations**: Lua scripts for check-and-decrement
- **Distributed**: Works across all worker instances

### Status Model Simplification
```python
campaign_status: Enum = ['DORMANT', 'PROCESSING', 'READY_FOR_REVIEW', 'READY_TO_SEND', 'SENT', 'ERROR', 'UNSUBSCRIBED']
processing_stage: String = 'property_data' | 'active_listings' | 'recent_sales' | 'market_data' | 'home_analysis' | 'email_creation' | 'idle'
```

### Fault Tolerance
- **Task timeouts**: Workers update `task_lock:{task_id}` with TTL in Redis
- **Stale task recovery**: Cron job requeues tasks where lock expired but status still PROCESSING
- **Visibility timeout**: Task stays invisible for 5 minutes, re-queued if not completed
- **Idempotency**: All operations check current state before modifying

## Implementation Files

### New Files to Create
- `python/shared_resources/redis_client.py` - Redis connection singleton
- `python/shared_resources/task_queue.py` - Queue operations (enqueue, dequeue, ack)
- `python/shared_resources/rate_limiter.py` - Centralized rate limiting with Redis
- `python/shared_resources/task_definitions.py` - Task types and schemas
- `python/task_producer/producer.py` - Polls DB and enqueues tasks
- `python/task_producer/Dockerfile` - New service
- `python/cron_jobs/task_recovery.py` - Recover stuck tasks

### Files to Modify
- `python/data_fetcher/data_fetcher.py` - Refactor from polling to queue consumption
- `python/email_manager/email_manager.py` - Refactor from polling to queue consumption
- `python/shared_resources/models.py` - Add new status fields, keep old ones
- `python/shared_resources/db_client.py` - Add new status queries, update locking strategy
- `python/shared_resources/rapid_api_zillow_client.py` - Use centralized rate limiter
- `python/shared_resources/rapid_api_zillow_client_2.py` - Use centralized rate limiter
- `python/shared_resources/rentcast_api_client.py` - Use centralized rate limiter
- `python/shared_resources/bedrock_client.py` - Use centralized rate limiter
- `python/shared_resources/quick_email_verification_client.py` - Use centralized rate limiter
- `compose.yaml` - Add Redis service, task_producer service
- `python/migrations/versions/` - New migration for status fields

## Dependencies
- Add `redis>=5.0.0` to all requirements.txt files
- Add `hiredis>=2.0.0` for performance

## Configuration
- Local: Docker Compose Redis service
- AWS: ElastiCache Redis (or EC2-hosted Redis)
- Environment variables: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` (optional)

## Testing Strategy
- Unit tests for rate limiter (mock Redis)
- Integration tests for queue operations
- Load tests with multiple workers
- Chaos tests (kill workers mid-task to verify recovery)

## Deployment
- Add Redis to `compose.yaml` 
- Update deployment scripts to provision Redis
- Run database migration
- Deploy with feature flag disabled
- Test new system in parallel
- Enable feature flag when validated
- Remove old polling code after 2 weeks of stable operation

## Implementation Todos

1. **redis-setup**: Add Redis service to compose.yaml and create redis_client.py singleton
2. **rate-limiter**: Implement centralized rate limiter in rate_limiter.py with token bucket algorithm (depends on: redis-setup)
3. **task-queue**: Create task queue abstraction in task_queue.py with enqueue/dequeue/ack operations (depends on: redis-setup)
4. **task-definitions**: Define task schemas and types in task_definitions.py (depends on: task-queue)
5. **db-migration**: Create Alembic migration to add processing_stage field to campaigns table
6. **update-api-clients**: Refactor all API clients to use centralized rate limiter instead of local threading locks (depends on: rate-limiter)
7. **task-producer**: Create task_producer service that polls database and enqueues tasks to Redis (depends on: task-queue, task-definitions)
8. **refactor-data-fetcher**: Refactor data_fetcher from polling threads to queue consumer workers (depends on: task-queue, task-definitions, update-api-clients)
9. **refactor-email-manager**: Refactor email_manager from polling threads to queue consumer workers (depends on: task-queue, task-definitions, refactor-data-fetcher)
10. **task-recovery**: Create cron job for recovering stuck/timed-out tasks (depends on: task-queue, task-definitions)
11. **testing**: Write integration tests for queue system, rate limiting, and fault recovery (depends on: refactor-data-fetcher, refactor-email-manager)
12. **deployment-updates**: Update deployment scripts and documentation for Redis provisioning (depends on: redis-setup)



