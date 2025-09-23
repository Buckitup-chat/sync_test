# Homework

## What could be improved

- UX improvements such as form validations
- Pagination
- Exponential backoff for sync, i just used 1 second
- Show connectivity status to the user
- Service worker for full offline support even after reload

## How to run

Start backend.
Start frontend in `client` directory:

```bash
npm install
npm run dev
```

The production build will only work if frontend `/api` is proxied to backend.