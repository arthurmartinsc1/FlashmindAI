import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="AsyncJob",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "kind",
                    models.CharField(
                        choices=[("generate_cards", "Gerar cards via IA")],
                        max_length=32,
                    ),
                ),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("pending", "Pendente"),
                            ("running", "Em execução"),
                            ("completed", "Concluído"),
                            ("failed", "Falhou"),
                        ],
                        default="pending",
                        max_length=16,
                    ),
                ),
                ("params", models.JSONField(blank=True, default=dict)),
                ("result", models.JSONField(blank=True, null=True)),
                ("error", models.TextField(blank=True, default="")),
                ("workflow_id", models.CharField(blank=True, default="", max_length=128)),
                ("run_id", models.CharField(blank=True, default="", max_length=128)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("started_at", models.DateTimeField(blank=True, null=True)),
                ("finished_at", models.DateTimeField(blank=True, null=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="async_jobs",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(fields=["user", "status"], name="jobs_user_status_idx"),
                    models.Index(fields=["kind", "status"], name="jobs_kind_status_idx"),
                ],
            },
        ),
    ]
