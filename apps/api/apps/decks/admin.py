from django.contrib import admin

from .models import Card, Deck


@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    list_display = ("title", "user", "is_public", "is_archived", "updated_at")
    list_filter = ("is_public", "is_archived")
    search_fields = ("title", "user__email")


@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display = ("id", "deck", "source", "ease_factor", "interval", "next_review")
    list_filter = ("source",)
    search_fields = ("front", "back", "deck__title")
