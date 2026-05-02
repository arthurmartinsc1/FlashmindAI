from django.contrib import admin

from .models import Review


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "card", "quality", "time_spent_ms", "reviewed_at")
    list_filter = ("quality",)
    search_fields = ("user__email", "card__id")
