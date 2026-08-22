class ScopeConfigurationKeysByTenant < ActiveRecord::Migration[8.1]
  def up
    remove_index :active_ingredients, :code
    remove_index :active_ingredients, :normalized_name
    add_index :active_ingredients, %i[organization_id code], unique: true
    add_index :active_ingredients, %i[organization_id normalized_name], unique: true,
      name: "index_active_ingredients_on_org_and_normalized_name"

    remove_index :delivery_zones, :code
    remove_index :delivery_zones, %i[governorate city name]
    add_index :delivery_zones, %i[organization_id code], unique: true
    add_index :delivery_zones, %i[organization_id governorate city name], unique: true,
      name: "index_delivery_zones_on_org_and_location_name"

    remove_index :loyalty_rules, :code
    add_index :loyalty_rules, %i[organization_id code], unique: true

    remove_index :coupons, name: "index_coupons_on_lower_normalized_code"
    add_index :coupons, "organization_id, lower(normalized_code)", unique: true,
      name: "index_coupons_on_org_and_lower_normalized_code"

    remove_index :search_synonyms, name: "index_search_synonyms_unique_pair"
    add_index :search_synonyms, %i[organization_id normalized_term normalized_expansion], unique: true,
      name: "index_search_synonyms_unique_pair_per_org"

    remove_index :drug_safety_rules, name: "index_drug_safety_rules_unique_version"
    remove_index :drug_safety_rules, name: "index_drug_safety_rules_single_active_version"
    add_index :drug_safety_rules, %i[organization_id code version], unique: true,
      name: "index_drug_safety_rules_unique_version_per_org"
    add_index :drug_safety_rules, %i[organization_id code], unique: true, where: "active",
      name: "index_drug_safety_rules_single_active_per_org"
  end

  def down
    remove_index :drug_safety_rules, name: "index_drug_safety_rules_single_active_per_org"
    remove_index :drug_safety_rules, name: "index_drug_safety_rules_unique_version_per_org"
    add_index :drug_safety_rules, %i[code version], unique: true, name: "index_drug_safety_rules_unique_version"
    add_index :drug_safety_rules, :code, unique: true, where: "active", name: "index_drug_safety_rules_single_active_version"

    remove_index :search_synonyms, name: "index_search_synonyms_unique_pair_per_org"
    add_index :search_synonyms, %i[normalized_term normalized_expansion], unique: true,
      name: "index_search_synonyms_unique_pair"

    remove_index :coupons, name: "index_coupons_on_org_and_lower_normalized_code"
    add_index :coupons, "lower(normalized_code)", unique: true, name: "index_coupons_on_lower_normalized_code"

    remove_index :loyalty_rules, %i[organization_id code]
    add_index :loyalty_rules, :code, unique: true

    remove_index :delivery_zones, name: "index_delivery_zones_on_org_and_location_name"
    remove_index :delivery_zones, %i[organization_id code]
    add_index :delivery_zones, %i[governorate city name], unique: true
    add_index :delivery_zones, :code, unique: true

    remove_index :active_ingredients, name: "index_active_ingredients_on_org_and_normalized_name"
    remove_index :active_ingredients, %i[organization_id code]
    add_index :active_ingredients, :normalized_name, unique: true
    add_index :active_ingredients, :code, unique: true
  end
end
