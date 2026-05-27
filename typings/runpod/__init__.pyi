from typing import Any

class _Serverless:
    def start(self, config: dict[str, Any]) -> Any: ...

serverless: _Serverless
