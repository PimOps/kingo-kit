# Connecting an AI assistant to JupyterLab

Kingo Kit includes Datalayer's Jupyter MCP Server as a containerized service. It lets an MCP-compatible AI assistant list notebooks, read and edit cells, execute code, inspect outputs, and work with kernels in the Kingo JupyterLab environment.

The service uses Streamable HTTP and is available only from the local computer by default:

```text
http://127.0.0.1:4040/mcp
```

The MCP endpoint requires a generated bearer token even though it is bound to loopback. Display the endpoint, token, and a ready-to-copy Claude Code command with:

```bash
kingo mcp
```

The bearer token is also shown by `kingo credentials` and stored in `~/.config/kingokit/.env` as `JUPYTER_MCP_TOKEN`. Do not publish it or commit it to Git.

## Claude Code

Copy the command printed by `kingo mcp`. Its form is:

```bash
claude mcp add kingo-jupyter \
  --transport http http://127.0.0.1:4040/mcp \
  --header "Authorization: Bearer YOUR_JUPYTER_MCP_TOKEN"
```

Claude Code is installed by Kingo Kit only on Ubuntu through the optional Ollama setup. On macOS and Windows, Kingo Kit does not install a host-native AI client; students may configure an MCP-compatible client they already use.

## Generic Streamable HTTP configuration

For clients that accept an HTTP MCP definition directly, use the following values:

```json
{
  "name": "kingo-jupyter",
  "transport": "http",
  "url": "http://127.0.0.1:4040/mcp",
  "headers": {
    "Authorization": "Bearer YOUR_JUPYTER_MCP_TOKEN"
  }
}
```

Client configuration formats differ, so consult the client's MCP documentation for the surrounding settings structure.

## Notebook files and execution

The MCP server connects to JupyterLab internally at `http://kingo-jupyter:8888`. It uses the same notebook root and Python environment as the browser:

- student files are under `/home/jovyan/work`, backed by `~/Kingokit` on the host;
- writable example notebooks are seeded under `/home/jovyan/work/jupyter_examples` without overwriting student edits;
- executed code has the data-science packages and Kingo database environment variables already supplied to JupyterLab.

The Jupyter image includes the real-time collaboration and MCP tools packages required by the upstream server. No local model is installed or downloaded.

## Troubleshooting

Check both services:

```bash
kingo health jupyter
kingo health jupyter-mcp
```

Restart only this integration:

```bash
kingo app jupyter-mcp restart
```

If an AI client reports `401 Unauthorized`, copy the current token from `kingo mcp` and ensure its header is exactly:

```text
Authorization: Bearer TOKEN
```

Keep `BIND_ADDRESS=127.0.0.1`. Changing it to `0.0.0.0` exposes an endpoint capable of editing notebooks and executing code. Bearer authentication remains required, but this classroom service is not intended as an internet-facing deployment.

Upstream project and documentation: [Datalayer Jupyter MCP Server](https://github.com/datalayer/jupyter-mcp-server).
