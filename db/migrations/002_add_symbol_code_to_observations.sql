-- UP
ALTER TABLE lizmap.observations ADD COLUMN symbol_code text;
UPDATE lizmap.observations
SET symbol_code = CASE
    WHEN "Deficiencies" ILIKE '%Erosion%' THEN 'erosion'
    WHEN "Deficiencies" ILIKE '%Exposure%' THEN 'exposure'
    WHEN "Deficiencies" ILIKE '%Forest Fire%' THEN 'forest_fire'
    WHEN "Deficiencies" ILIKE '%Geohaz%' THEN 'geohaz'
    WHEN "Deficiencies" ILIKE '%Observed Spill%' THEN 'observed_spill'
    WHEN "Deficiencies" ILIKE '%Over Growth%' THEN 'over_growth'
    WHEN "Deficiencies" ILIKE '%Public Enc%' THEN 'public_enc'
    WHEN "Deficiencies" ILIKE '%Sign Missing%' THEN 'sign_missing'
    WHEN "Deficiencies" ILIKE '%Third Party%' THEN 'third_party'
    WHEN "Deficiencies" ILIKE '%Above Ground Pipe%' THEN 'above_ground_pipe'
    WHEN "Deficiencies" ILIKE '%Active Construction%' THEN 'active_construction'
    WHEN "Deficiencies" ILIKE '%Riser%' THEN 'riser'
    WHEN "Deficiencies" ILIKE '%Open_Ditch%' THEN 'open_ditch'
    WHEN "Deficiencies" ILIKE '%Open Ditch%' THEN 'open_ditch'
    WHEN "Deficiencies" ILIKE '%Patterned Holes%' THEN 'patterned_holes'
    WHEN "Deficiencies" ILIKE '%Pipe Bridge%' THEN 'pipe_bridge'
    WHEN "Deficiencies" ILIKE '%Beaver%' THEN 'beaver'
    ELSE 'other'
END;

-- DOWN
ALTER TABLE lizmap.observations DROP COLUMN symbol_code;
