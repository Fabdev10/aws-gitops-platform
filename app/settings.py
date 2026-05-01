from dataclasses import dataclass
from functools import lru_cache
from os import getenv


def _csv_env(name: str) -> tuple[str, ...]:
    raw_value = getenv(name, "")
    return tuple(item.strip() for item in raw_value.split(",") if item.strip())


@dataclass(frozen=True)
class RuntimeSettings:
    service_name: str
    environment: str
    version: str
    aws_region: str
    git_sha: str
    log_level: str
    required_secrets: tuple[str, ...]

    @property
    def configured_secret_count(self) -> int:
        return len(self.required_secrets)


@lru_cache
def get_settings() -> RuntimeSettings:
    return RuntimeSettings(
        service_name=getenv("APP_NAME", "aws-gitops-platform"),
        environment=getenv("APP_ENV", "local"),
        version=getenv("APP_VERSION", "0.1.0"),
        aws_region=getenv("AWS_REGION", "local"),
        git_sha=getenv("GIT_SHA", "dev"),
        log_level=getenv("LOG_LEVEL", "INFO"),
        required_secrets=_csv_env("REQUIRED_SECRETS"),
    )