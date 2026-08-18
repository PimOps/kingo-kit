const endpoint = "http://kingo-n8n:5678/rest/owner/setup";
const response = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    email: process.env.N8N_OWNER_EMAIL,
    firstName: "Kingo",
    lastName: "User",
    password: process.env.N8N_OWNER_PASSWORD,
  }),
});

if (response.ok) {
  console.log("Created the default n8n owner account.");
  process.exit(0);
}

const body = await response.text();
if (response.status === 400 && /owner already|already setup|already.*owner/i.test(body)) {
  console.log("The n8n owner account is already configured; leaving it unchanged.");
  process.exit(0);
}

throw new Error(`Could not configure the n8n owner (${response.status}): ${body}`);
