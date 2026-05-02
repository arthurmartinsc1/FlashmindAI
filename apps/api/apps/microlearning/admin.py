from django.contrib import admin

from .models import ContentBlock, MicroLesson, UserLessonCompletion


class ContentBlockInline(admin.TabularInline):
    model = ContentBlock
    extra = 0
    fields = ("order", "type", "content")
    ordering = ("order",)


@admin.register(MicroLesson)
class MicroLessonAdmin(admin.ModelAdmin):
    list_display = ("title", "deck", "order", "estimated_minutes", "updated_at")
    search_fields = ("title", "deck__title")
    inlines = [ContentBlockInline]


@admin.register(ContentBlock)
class ContentBlockAdmin(admin.ModelAdmin):
    list_display = ("id", "lesson", "type", "order")
    list_filter = ("type",)


@admin.register(UserLessonCompletion)
class UserLessonCompletionAdmin(admin.ModelAdmin):
    list_display = ("user", "lesson", "completed_at")
    search_fields = ("user__email", "lesson__title")
