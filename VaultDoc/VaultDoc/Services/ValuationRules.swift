import Foundation

struct ValuationRules {
    struct CategoryRule {
        let annualFactor: Double
        let floorFactor: Double
        let baselineValue: Double
    }

    static let documentationPhotoWeight = 0.6
    static let documentationDocumentWeight = 0.4
    static let documentationValueBoost = 0.08
    static let notesMultiplier = 1.03
    static let serialNumberMultiplier = 1.02
    static let remoteValuationEnabled = false

    static var defaultCountryCode: String {
        Locale.autoupdatingCurrent.region?.identifier ?? "US"
    }

    static func objectValuationPrompt(
        nameHint: String,
        categoryHint: String,
        purchasePrice: Double,
        purchaseDate: Date,
        currency: String,
        countryCode: String
    ) -> String {
        let purchaseYear = Calendar.current.component(.year, from: purchaseDate)
        let countryName = Locale.autoupdatingCurrent.localizedString(forRegionCode: countryCode) ?? countryCode

        return """
        You are an object valuation engine.

        Task:
        Given one or more images and optional metadata, determine whether the main subject can be valued as a non-living physical object and estimate its current market value.

        Core eligibility rules:
        1. The main subject must be a non-living tangible object.
        2. Return supported=false if the main subject is primarily any of the following: person, animal, plant, food, liquid, gas, flame, smoke, weather, digital-only item with no physical object being valued, scene with no clear primary object, or property, land, or building.
        3. If multiple objects are visible, identify the single primary object that is most central, prominent, and likely intended for valuation. Ignore secondary items unless they help identify the primary object.
        4. If the object category is difficult to value from image evidence alone, attempt identification first and return supported=false only when a credible valuation cannot be produced.

        Identification rules:
        5. Identify the object as specifically as possible.
        6. Infer and extract every reliably observable or reasonably inferable attribute where applicable, including object_type, category, subcategory, make, brand, manufacturer, model, variant, generation, series, edition, year_or_year_range, material, color, finish, size, dimensions, capacity, storage, specification, configuration, region_or_market_variant, serial_or_part_number, distinguishing_features, included_accessories, missing_parts, modifications, and authenticity signals.
        7. Use only evidence from the images and supplied metadata. Every important inference must be confidence scored.
        8. If make or model is uncertain, include best-guess values inside the primary object fields where appropriate and provide alternative_identifications.
        9. Never invent exact identifiers. Use null for unknown values.

        Condition rules:
        10. Assess visible condition in detail from image evidence only.
        11. Include condition fields where applicable, including overall_condition, condition_grade, wear_level, cosmetic_damage, structural_damage, functional_risk, cleanliness, age_signs, screen_or_surface_damage, rust_or_corrosion, cracks_or_dents, missing_components, repair_indicators, box_present, documents_present, and accessories_present.
        12. Separate visible facts from inferred risks.
        13. If condition cannot be fully assessed, state the uncertainty explicitly and widen the valuation range.

        Valuation rules:
        14. Estimate current market value based on object identification, visible condition, apparent completeness, age or likely age, country or market, and current resale conventions for that object category.
        15. Do not use purchase price as an input to the valuation.
        16. If purchase date is provided, use it only as a weak contextual signal for likely age, not as a direct depreciation anchor.
        17. Value the object as it appears today in its likely local resale market.
        18. Prefer fair market resale value: the price a typical informed buyer would likely pay a typical informed seller in the given country.
        19. Return both estimated_value_single and estimated_value_range.
        20. Widen the range when make, model, authenticity, functionality, completeness, condition, market, region, or age is uncertain.
        21. If country is not clearly provided, only infer market when strongly supported; otherwise use a broad international secondary market assumption and note it in reasoning.
        22. If there is insufficient evidence for a credible value, return supported=false.

        Confidence and support rules:
        23. Every important conclusion must include confidence from 0 to 1 and evidence_basis set to visible, inferred, user_provided, or mixed where applicable.
        24. Provide separate confidence values for object_detection_confidence, category_confidence, brand_confidence, model_confidence, condition_confidence, and valuation_confidence.
        25. If authenticity cannot be determined, do not assume authenticity for luxury, collectible, or branded goods with high counterfeit exposure.
        26. Return supported=true only if the subject is non-living, a primary object can be identified, the category is reasonably valuable from the available evidence, and a credible valuation range can be estimated.
        27. Return supported=false if the main subject is living, no clear primary object exists, identification is too weak, the object is too obscured/distant/incomplete, or image quality is too poor.

        Output rules:
        28. Return JSON only.
        29. Do not return markdown.
        30. Do not include explanatory text outside the JSON.
        31. Use null for unknown fields.
        32. Include concise reasoning fields inside JSON.

        Context:
        - Name hint: \(nameHint.isEmpty ? "None" : nameHint)
        - Category hint: \(categoryHint)
        - Purchase price: \(purchasePrice) (metadata only, do not use for valuation)
        - Purchase year: \(purchaseYear)
        - Country: \(countryName) (\(countryCode))
        - Currency: \(currency)

        Return this JSON shape:
        {
          "supported": true,
          "primary_object": {
            "object_type": null,
            "category": null,
            "subcategory": null,
            "make": null,
            "brand": null,
            "manufacturer": null,
            "model": null,
            "variant": null,
            "generation": null,
            "series": null,
            "edition": null,
            "year_or_year_range": null,
            "material": null,
            "color": null,
            "finish": null,
            "size": null,
            "dimensions": null,
            "capacity": null,
            "storage": null,
            "specification": null,
            "configuration": null,
            "region_or_market_variant": null,
            "serial_or_part_number": null,
            "distinguishing_features": [],
            "included_accessories": [],
            "missing_parts": [],
            "modifications": [],
            "authenticity_assessment": {
              "status": null,
              "confidence": null,
              "notes": null
            }
          },
          "alternative_identifications": [
            {
              "make": null,
              "model": null,
              "variant": null,
              "confidence": null
            }
          ],
          "condition": {
            "overall_condition": null,
            "condition_grade": null,
            "wear_level": null,
            "cosmetic_damage": [],
            "structural_damage": [],
            "functional_risk": [],
            "cleanliness": null,
            "age_signs": [],
            "screen_or_surface_damage": [],
            "rust_or_corrosion": null,
            "cracks_or_dents": [],
            "missing_components": [],
            "repair_indicators": [],
            "box_present": null,
            "documents_present": null,
            "accessories_present": []
          },
          "market_context": {
            "country": null,
            "currency": null,
            "market_scope": null,
            "valuation_basis": "fair_market_resale"
          },
          "valuation": {
            "estimated_value_single": null,
            "estimated_value_range": {
              "min": null,
              "max": null
            },
            "confidence": null,
            "value_drivers": [],
            "uncertainty_factors": []
          },
          "confidence": {
            "object_detection_confidence": null,
            "category_confidence": null,
            "brand_confidence": null,
            "model_confidence": null,
            "condition_confidence": null,
            "valuation_confidence": null
          },
          "reasoning": {
            "visible_facts": [],
            "inferred_facts": [],
            "summary": null
          }
        }
        """
    }

    static func textOnlyValuationPrompt(
        name: String,
        category: String,
        currency: String,
        purchasePrice: Double,
        purchaseDate: Date
    ) -> String {
        """
        You are a valuables appraiser. Given this item:
        - Name: \(name)
        - Category: \(category)
        - Purchase price: \(currency) \(purchasePrice)
        - Year purchased: \(YearFormatter.year(from: purchaseDate))

        Estimate the current market value.
        Reply with ONLY a number, no currency symbol, no explanation.
        """
    }

    static func categoryRule(for category: String) -> CategoryRule {
        switch category {
        case "electronics":
            return CategoryRule(annualFactor: 0.85, floorFactor: 0.20, baselineValue: 150)
        case "furniture":
            return CategoryRule(annualFactor: 0.94, floorFactor: 0.35, baselineValue: 300)
        case "art":
            return CategoryRule(annualFactor: 1.04, floorFactor: 0.80, baselineValue: 500)
        case "jewellery":
            return CategoryRule(annualFactor: 1.03, floorFactor: 0.85, baselineValue: 400)
        case "collectibles":
            return CategoryRule(annualFactor: 1.05, floorFactor: 0.90, baselineValue: 250)
        default:
            return CategoryRule(annualFactor: 0.98, floorFactor: 0.50, baselineValue: 100)
        }
    }

    static func countryMultiplier(for countryCode: String) -> Double {
        switch countryCode.uppercased() {
        case "CH", "NO":
            return 1.12
        case "GB", "IE", "US", "CA", "AU", "NZ":
            return 1.05
        case "JP", "SG", "AE":
            return 1.08
        default:
            return 1.0
        }
    }
}
