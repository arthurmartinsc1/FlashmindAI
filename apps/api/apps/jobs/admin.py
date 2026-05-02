from django.contrib import admin

from .models import AsyncJob


@admin.register(AsyncJob)
class AsyncJobAdmin(admin.ModelAdmin):
    list_display = ("id", "kind", "status", "user", "created_at", "finished_at")
    list_filter = ("kind", "status")
    search_fields = ("id", "workflow_id", "user__email")
    readonly_fields = (
        "id",
        "workflow_id",
        "run_id",
        "created_at",
        "updated_at",
        "started_at",
        "finished_at",
    )
