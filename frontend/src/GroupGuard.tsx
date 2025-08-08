import { useMsal, useAccount } from "@azure/msal-react";
import React, { useEffect, useState } from "react";
import { allowedGroupIds, loginRequest } from "./authConfig";
import { Box, Button, Spinner, Text } from "@chakra-ui/react";

export default function GroupGuard({ children }: { children: React.ReactNode }) {
  const { instance, accounts } = useMsal();
  const account = useAccount(accounts[0] || {});
  const [allowed, setAllowed] = useState<boolean | null>(null);

  useEffect(() => {
    if (!account?.idTokenClaims) return;
    const claims: any = account.idTokenClaims;
    const groups: string[] = claims.groups || [];
    const hasGroupsOverage = claims.hasgroups === "true" || claims.hasgroups === true;
    if (groups.length > 0) {
      setAllowed(groups.some((g) => allowedGroupIds.includes(g)));
    } else if (hasGroupsOverage) {
      // Enterprise-safe default: require group filtering or app roles
      setAllowed(false);
    } else {
      setAllowed(false);
    }
  }, [account]);

  if (!account) {
    return (
      <Box p={8} textAlign="center">
        <Button colorScheme="blue" size="lg" onClick={() => instance.loginRedirect(loginRequest)}>
          Sign in with Microsoft
        </Button>
      </Box>
    );
  }

  if (allowed === null) {
    return (
      <Box p={8} textAlign="center">
        <Spinner />
      </Box>
    );
  }

  if (!allowed) {
    return (
      <Box p={8} textAlign="center" color="red.500">
        <Text>Not authorized. Ask IT to add you to the allowed group(s) or configure roles.</Text>
      </Box>
    );
  }

  return <>{children}</>;
}
