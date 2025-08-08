import React, { useState, useRef, useEffect } from "react";
import {
  ChakraProvider, Box, Button, Input, VStack, HStack, Text, useToast,
  IconButton, Switch, FormControl, FormLabel, Select, Badge
} from "@chakra-ui/react";
import { MsalProvider, useMsal, useAccount } from "@azure/msal-react";
import { PublicClientApplication } from "@azure/msal-browser";
import { msalConfig, loginRequest, tokenRequest, apiUrl } from "./authConfig";
import GroupGuard from "./GroupGuard";

const msalInstance = new PublicClientApplication(msalConfig);

type Msg = { role: "user" | "assistant" | "system"; content: string };

const DEFAULT_SYSTEM = "You are a helpful enterprise assistant.";
const DEFAULT_MODEL = "gpt-4o-mini";

function useAutoScroll(dep: any) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => { ref.current?.scrollIntoView({ behavior: "smooth" }); }, [dep]);
  return ref;
}

function Chat() {
  const { instance, accounts } = useMsal();
  const account = useAccount(accounts[0] || {});
  const toast = useToast();
  const [messages, setMessages] = useState<Msg[]>([{ role: "system", content: DEFAULT_SYSTEM }]);
  const [input, setInput] = useState("");
  const [model, setModel] = useState(DEFAULT_MODEL);
  const [streaming, setStreaming] = useState(true);
  const [dark, setDark] = useState(false);
  const [usage, setUsage] = useState<{ prompt_tokens?: number; completion_tokens?: number; total_tokens?: number }>({});
  const bottomRef = useAutoScroll(messages);

  useEffect(() => {
    document.body.style.background = dark ? "#0f172a" : "#f7fafc";
  }, [dark]);

  const sendMessage = async () => {
    if (!input.trim()) return;
    const userMsg: Msg = { role: "user", content: input };
    setMessages((m) => [...m, userMsg]);
    setInput("");

    try {
      const token = (await instance.acquireTokenSilent(tokenRequest(account))).accessToken;

      const body = {
        model,
        messages: messages.concat(userMsg).map((m) => ({ role: m.role, content: m.content })),
        temperature: 0.2,
        stream: streaming
      };

      if (streaming) {
        // SSE streaming
        const res = await fetch(`${apiUrl}/chat/completions`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`
          },
          body: JSON.stringify(body)
        });
        if (!res.ok && res.status !== 200) throw new Error(`HTTP ${res.status}`);

        const reader = res.body!.getReader();
        const decoder = new TextDecoder("utf-8");
        let assistant = "";
        let done = false;
        setMessages((m) => [...m, { role: "assistant", content: "" }]);

        while (!done) {
          const { value, done: d } = await reader.read();
          done = d;
          if (value) {
            const chunk = decoder.decode(value, { stream: true });
            const lines = chunk.split("\n").filter(Boolean);
            for (const line of lines) {
              if (line.startsWith("data: ")) {
                const data = line.slice(6).trim();
                if (data === "[DONE]") { done = true; break; }
                try {
                  const json = JSON.parse(data);
                  const delta = json.choices?.[0]?.delta?.content ?? "";
                  assistant += delta || "";
                  setMessages((m) => {
                    const copy = [...m];
                    const last = copy[copy.length - 1];
                    if (last && last.role === "assistant") {
                      last.content = assistant;
                    }
                    return copy;
                  });
                  if (json.usage) setUsage(json.usage);
                } catch {}
              }
            }
          }
        }
      } else {
        const res = await fetch(`${apiUrl}/chat/completions`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`
          },
          body: JSON.stringify(body)
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        const reply = json.choices?.[0]?.message?.content || "";
        setMessages((m) => [...m, { role: "assistant", content: reply }]);
        if (json.usage) setUsage(json.usage);
      }
    } catch (e: any) {
      toast({ status: "error", title: "API error", description: e.message });
    }
  };

  return (
    <VStack h="100vh" w="100vw" p={4} spacing={4} align="center">
      <Box w="100%" maxW="960px" borderRadius="xl" bg={dark ? "gray.800" : "white"} p={6} shadow="lg">
        <HStack justify="space-between" mb={4}>
          <Text fontSize="2xl" fontWeight="bold" color={dark ? "white" : "black"}>
            🤖 OpenAI Enterprise Chat
          </Text>
          <HStack>
            <Badge>{model}</Badge>
            <FormControl display="flex" alignItems="center">
              <FormLabel htmlFor="stream" mb="0" color={dark ? "gray.200" : "gray.700"}>
                Stream
              </FormLabel>
              <Switch id="stream" isChecked={streaming} onChange={(e) => setStreaming(e.target.checked)} />
            </FormControl>
            <FormControl display="flex" alignItems="center">
              <FormLabel htmlFor="dark" mb="0" color={dark ? "gray.200" : "gray.700"}>
                Dark
              </FormLabel>
              <Switch id="dark" isChecked={dark} onChange={(e) => setDark(e.target.checked)} />
            </FormControl>
          </HStack>
        </HStack>

        <HStack mb={3}>
          <Select value={model} onChange={(e) => setModel(e.target.value)} maxW="sm">
            <option value="gpt-4o-mini">gpt-4o-mini</option>
            <option value="gpt-4o">gpt-4o</option>
          </Select>
          <Button size="sm" onClick={() => setMessages([{ role: "system", content: DEFAULT_SYSTEM }])}>
            Reset
          </Button>
        </HStack>

        <Box h="60vh" overflowY="auto" mb={4} p={2} bg={dark ? "gray.900" : "gray.50"} borderRadius="md">
          {messages.map((m, i) => (
            <HStack key={i} justify={m.role === "user" ? "flex-end" : "flex-start"} mb={2}>
              <Box
                bg={m.role === "user" ? (dark ? "blue.700" : "blue.100") : (dark ? "gray.700" : "gray.100")}
                color={dark ? "white" : "black"}
                px={4}
                py={2}
                borderRadius="lg"
                maxW="70%"
              >
                <Text whiteSpace="pre-wrap">{m.content}</Text>
              </Box>
            </HStack>
          ))}
          <div ref={bottomRef as any} />
        </Box>

        <HStack>
          <Input
            placeholder="Ask something..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") sendMessage(); }}
          />
          <IconButton aria-label="Send" onClick={sendMessage} icon={<span>📤</span> as any} />
        </HStack>

        <HStack mt={3} spacing={4}>
          {usage.total_tokens != null && (
            <Text fontSize="sm" color={dark ? "gray.300" : "gray.600"}>
              Usage: {usage.total_tokens} tokens
            </Text>
          )}
        </HStack>
      </Box>
    </VStack>
  );
}

function RootApp() {
  return (
    <ChakraProvider>
      <MsalProvider instance={msalInstance}>
        <GroupGuard>
          <Chat />
        </GroupGuard>
      </MsalProvider>
    </ChakraProvider>
  );
}

export default RootApp;
