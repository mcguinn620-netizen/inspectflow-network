INSERT INTO public.lemonsquad_field_maps (form_key, form_hash, mapping_json, sample_fields_json)
VALUES (
  'inspection_report',
  'v7-2026-07',
  jsonb_build_object(
    'sections', jsonb_build_array('Upload Images','Upload Video','Vehicle Info','Warranty Info','Engine','Road Test','Findings','Edit Images','Review'),
    'fields', jsonb_build_object(
      'road_test.performed',        jsonb_build_object('section','Road Test','selector','input[name="road_test_performed"]','type','radio','options',jsonb_build_array('Yes','No'),'source','inspection.road_test.completed'),
      'findings.verbal_required',   jsonb_build_object('section','Findings','selector','input[name="verbal_required"]','type','radio','options',jsonb_build_array('Yes','No'),'source','inspection.verbal_required'),
      'findings.person_spoken_to',  jsonb_build_object('section','Findings','selector','input[name="person_spoken_to"]','type','text','source','inspection.verbal.contact_name'),
      'findings.time_of_call',      jsonb_build_object('section','Findings','selector','input[name="time_of_call"]','type','text','placeholder','e.g. 2:30 PM','source','inspection.verbal.time'),
      'findings.reason_for_inspection', jsonb_build_object('section','Findings','selector','textarea[name="reason_for_inspection"]','type','textarea','source','inspection_request.customer_complaint','readonly',true),
      'findings.state_of_assembly', jsonb_build_object('section','Findings','selector','textarea[name="state_of_assembly"]','type','textarea','source','inspection.state_of_assembly'),
      'findings.suspected_cause',   jsonb_build_object('section','Findings','selector','textarea[name="suspected_cause_of_failure"]','type','textarea','source','inspection.suspected_cause'),
      'findings.concern_reproduced',jsonb_build_object('section','Findings','selector','input[name="concern_reproduced"]','type','radio','options',jsonb_build_array('Yes','No'),'source','inspection.concern_reproduced'),
      'findings.inspector_observations', jsonb_build_object('section','Findings','selector','textarea[name="inspector_observations"]','type','textarea','source','inspection.notes'),
      'images.caption',             jsonb_build_object('section','Edit Images','selector','input[name^="image_caption_"]','type','text','source','photo.caption','per_photo',true),
      'images.annotation',          jsonb_build_object('section','Edit Images','selector','select[name^="image_annotation_"]','type','select','options',jsonb_build_array('Cover Photo','Front of Repair Facility','OBD2 Image','VIN Image','Odometer Reading','Undercarriage'),'source','photo.annotation','per_photo',true)
    ),
    'required_annotations', jsonb_build_array('Cover Photo','Front of Repair Facility','OBD2 Image','VIN Image','Odometer Reading','Undercarriage'),
    'nav', jsonb_build_object('next_selector','button:has-text("Next")','save_selector','button:has-text("Save!!")','save_quit_selector','button:has-text("Save & Quit")','submit_selector','button:has-text("Submit Job")'),
    'submission_mode_default','draft_only'
  ),
  jsonb_build_object('captured_from','user screenshots IMG_0370..IMG_0374','captured_at','2026-07-08')
)
ON CONFLICT (form_key, form_hash) DO UPDATE
  SET mapping_json = EXCLUDED.mapping_json,
      sample_fields_json = EXCLUDED.sample_fields_json,
      updated_at = now();