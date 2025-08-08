# OpenAI Enterprise Chat Frontend

Features:
- MSAL SSO + group-based authorization (with group overage protection)
- Streaming SSE from Azure OpenAI via APIM
- Model picker, dark mode, token usage display, reset
- All config via environment variables

## Env
See `.env.example`. Set these as CI/CD vars in GitLab.

## Local
```
npm ci
npm start
```

## Build
```
npm run build
```

## Deploy
- GitLab Pages via `.gitlab-ci.yml`
- Or deploy `build/` to Azure Web App (configure CORS on APIM for your origin)
