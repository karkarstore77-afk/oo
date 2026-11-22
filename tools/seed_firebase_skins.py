"""Create/update the complete RoofGroove skin catalog in Cloud Firestore.

Uses Google Application Default Credentials. Existing promo codes and token values are preserved.
Run as a trusted project admin; never ship admin credentials with the game.
"""

from __future__ import annotations

import argparse

from google.cloud import firestore


BASE_SKINS = {
    "classic": "Knight",
    "wizard": "Wizard",
    "pirate": "Pirate",
    "viking": "Viking",
    "ninja": "Ninja",
    "king": "King",
    "bunny": "Bunny Girl",
    "fairy": "Fairy",
    "princess": "Princess",
    "dev": "Developers",
}
SPECIES = [
    "Robot", "Alien", "Frog", "Cat", "Bear", "Skeleton", "Mushroom", "Pumpkin", "Imp", "Penguin",
    "Fox", "Owl", "Drake", "Ghost", "Slime", "Cactus", "Snowman", "Astronaut", "Zombie", "Cyclops",
]
VARIANTS = ["", "Scout", "Hiker", "Dandy", "Golden"]


def catalog() -> dict[str, str]:
    skins = dict(BASE_SKINS)
    for i in range(100):
        species = SPECIES[i % len(SPECIES)]
        variant = i // len(SPECIES)
        name = f"Golden {species}" if variant == 4 else (species if variant == 0 else f"{species} {VARIANTS[variant]}")
        skins[f"g{i + 1:03d}"] = name
    return skins


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="roof-groove", help="Firebase / Google Cloud project ID")
    args = parser.parse_args()

    db = firestore.Client(project=args.project)
    batch = db.batch()
    count = 0
    for skin_id, name in catalog().items():
        ref = db.collection("skins").document(skin_id)
        snapshot = ref.get()
        fields = {"skin_id": skin_id, "name": name}
        if not snapshot.exists:
            fields.update({"code": "", "tokens": 0})
        batch.set(ref, fields, merge=True)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    if count % 400:
        batch.commit()
    print(f"Synced {count} skin documents to {args.project}/skins. Existing reward codes were preserved.")


if __name__ == "__main__":
    main()
