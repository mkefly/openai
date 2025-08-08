export const apiUrl = process.env.REACT_APP_API_URL || "";

export const msalConfig = {
  auth: {
    clientId: process.env.REACT_APP_AAD_CLIENT_ID!,
    authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AAD_TENANT_ID}`,
    redirectUri: window.location.origin
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false
  }
};

export const allowedGroupIds = (process.env.REACT_APP_AAD_GROUP_IDS || "")
  .split(",")
  .map((g) => g.trim())
  .filter(Boolean);

const apiScope = process.env.REACT_APP_AAD_API_SCOPE!; // e.g., api://apim-openai/access

export const loginRequest = {
  scopes: ["openid", "profile", apiScope]
};

export const tokenRequest = (account: any) => ({
  scopes: [apiScope],
  account
});
