/**
 * Ingredient checklist items for catering dishes (from lib/assets/sads.csv).
 * Keys are uppercased dish names; values are lowercase ingredient labels.
 */
export const CATERING_DISH_INGREDIENTS = {
  'PLAIN RICE': ['white rice'],
  'BEEF KALITIRAN WITH MUSHROOM': ['beef', 'mushroom'],
  'CHICKEN CORDON BLEU': ['chicken', 'ham', 'cheese'],
  'PORK KALDERETA': ['pork', 'potatoes', 'carrots'],
  'SOTANGHON GUISADO': ['sotanghon', 'shrimp', 'mixed vegetables'],
  'BUKO PANDAN': ['buko', 'gelatin powder', 'pandan'],
  'FOUR SEASONS JUICE': ['mixed fruits'],
  'ARROZ VALENCIANA RICE': ['white rice', 'chicken', 'chorizo', 'shrimp', 'vegetables'],
  'BEEF STROGANOFF': ['beef', 'mushrooms', 'cream'],
  'BUFFALO WINGS': ['chicken wings', 'buffalo sauce', 'butter'],
  'PORK HUMBA': ['pork', 'soy sauce', 'garlic'],
  'BAKED MAC': ['macaroni pasta', 'cheese', 'meat sauce'],
  'MANGO TAPIOCA': ['mango', 'small boba pearls', 'cream'],
  'LEMON ICED TEA JUICE': ['lemon', 'tea'],
  'JAVA RICE': ['white rice', 'garlic', 'turmeric'],
  'BEEF WITH BROCCOLI': ['beef', 'broccoli'],
  'CHICKEN PASTEL': ['chicken', 'all purpose cream', 'potatoes', 'carrots'],
  'FISH FILLET': ['fish', 'flour'],
  'SHRIMP CAMARON': ['shrimp', 'flour'],
  'CHOPSUEY': ['mixed vegetables', 'shrimp', 'quail eggs'],
  'CATHEDRAL FRUITY JELLY': ['fruit', 'jelly', 'cream'],
  'ORANGE JUICE': ['orange'],
  'SHRIMP CROQUETTE WITH DRIED TOMATO SAUCE': ['shrimp', 'tomato', 'bread crumbs', 'cream'],
  'PORK TONKATSU': ['pork', 'bread crumbs'],
  'ROAST BEEF': ['beef', 'gravy'],
  'VEGETABLE SALAD': ['mixed vegetables', 'salad dressing'],
  'BEEF STEW': ['beef', 'potatoes', 'carrots', 'tomato'],
  'CHICKEN AND HAM TENDERS': ['chicken', 'ham', 'bread crumbs'],
  'FISH FILLET WITH BACON SAUCE': ['fish', 'flour', 'bacon', 'cream'],
  'MAC N CHEESE': ['macaroni', 'cheese'],
  'BLUE RICE': ['white rice', 'blue pea flower'],
  'HAM N CHEESE ROLL WITH SWEET N SOUR SAUCE': ['ham', 'cheese', 'sweet and sour sauce'],
  'BAKED PORK MEATBALLS WITH CREAM SAUCE': ['pork', 'bread crumbs', 'cream'],
  'MIXED VEGETABLES FRITTATA': ['eggs', 'mixed vegetables', 'cheese'],
  'FRESH FRUITS': ['assorted fruits'],
  'FRUITY JELLY': ['fruit', 'jelly'],
  'LEMON CUCUMBER JUICE': ['lemon', 'cucumber'],
};

/** Backfill empty catering dish ingredients from the seed map. */
export async function backfillCateringDishIngredients(pool) {
  const result = await pool.query(
    `SELECT id, name, ingredients
     FROM menu_dishes
     WHERE category = 'catering'
       AND archived = false
       AND jsonb_array_length(COALESCE(ingredients, '[]'::jsonb)) = 0`,
  );

  if (result.rows.length === 0) return 0;

  let updated = 0;
  for (const row of result.rows) {
    const key = String(row.name ?? '').trim().toUpperCase();
    const ingredients = CATERING_DISH_INGREDIENTS[key];
    if (!ingredients?.length) continue;

    await pool.query(
      `UPDATE menu_dishes
       SET ingredients = $1::jsonb, updated_at = now()
       WHERE id = $2`,
      [JSON.stringify(ingredients), row.id],
    );
    updated += 1;
  }

  if (updated > 0) {
    console.log(`[initDb] Backfilled ingredients for ${updated} catering dish(es).`);
  }

  return updated;
}
