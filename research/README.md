# Research Reference Files

This folder contains all the scientific data and reference materials needed to implement the Smart Slushi app. These files are designed to be referenced by the coding agent without requiring additional web searches.

## Files

### `slush-science.md`
Core scientific principles behind frozen drinks:
- What Brix is and why it matters (target: 13-15%)
- What ABV is and its limits (target: 0-10%)
- Freezing point calculations
- Ninja Slushi machine specifications
- Troubleshooting guide

### `ingredient-database.json`
Complete JSON database of 100+ ingredients with:
- ABV percentages (0-100)
- Brix percentages (0-100)
- Categories (spirit, liqueur, sweetener, citrus, juice, puree, dairy, mixer, wine, bitters)
- Notes where applicable

Categories include:
- Spirits (vodka, gin, tequila, rum, whiskey, etc.)
- Liqueurs (triple sec, Cointreau, Aperol, Kahlua, etc.)
- Sweeteners (simple syrups, agave, honey, etc.)
- Citrus (lime, lemon, orange, grapefruit)
- Juices (pineapple, cranberry, mango, etc.)
- Purees (strawberry, mango, passion fruit, etc.)
- Dairy/Cream (coconut cream, milk, cream)
- Mixers (water, tonic, ginger beer, cola)
- Wine/Beer (rosé, prosecco, vermouth)

### `recipe-templates.json`
15 pre-tested recipe templates including:
- Classic Frozen Margarita
- Ford Fry's batch Margarita (proven production recipe)
- Tommy's Margarita
- Frozen Daiquiri
- Strawberry Daiquiri
- Piña Colada
- Frosé
- Frozen Paloma
- Frozen Cosmopolitan
- Frozen Mojito
- And more...

Each template includes:
- Base ingredient ratios
- Expected ABV and Brix for single serving
- Machine-ready adjustments (water ratio, sweetener additions)
- Tags for categorization

### `calculation-formulas.md`
Complete Swift code implementations for:
- Unit conversions (oz ↔ ml ↔ cups, etc.)
- Final ABV calculation (volume-weighted average)
- Final Brix calculation (volume-weighted average)
- Freezing point calculation
- Optimal Brix range based on ABV
- Auto-balance algorithm (add water/sweetener to hit targets)
- Recipe scaling
- User preference mapping (sliders → target ranges)
- Slushability status evaluation
- Rounding rules for display

### Source Documents (Binary)
- `slushi-batching.xlsx` - Original spreadsheet calculator with formulas
- `ford-fry-drink-bible.docx` - Restaurant drink recipes and guidelines

## Quick Reference

### Target Ranges
| Parameter | Optimal | Acceptable | Will Not Work |
|-----------|---------|------------|---------------|
| Brix | 13-15% | 11-17% | <11% or >18% |
| ABV | 5-10% | 0-12% | >12% |

### Key Formulas
```
Final ABV = Σ(volume × ABV) / total_volume
Final Brix = Σ(volume × Brix) / total_volume
Freezing Point (°C) = -0.4 × ABV%
```

### Common Adjustments
- **ABV too high**: Add water (dilutes both ABV and Brix)
- **Brix too low**: Add simple syrup or sweetener
- **Brix too high**: Add water

### Ninja Slushi Specs
- 72oz model: ~64oz working capacity
- 88oz model: ~80oz working capacity
- Operating temp: -6°C to -10°C (21°F to 14°F)
- Freeze time: 15-60 minutes
