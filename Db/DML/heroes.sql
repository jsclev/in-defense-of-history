-- (no semicolons in comments -- the block splitter cuts on them)
-- nickname NULL = no genuine historical nickname exists
INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name
) VALUES
(
    '75a615ca-f880-44ca-8386-e28f72fe2f7f', 'Israel Putnam', 'Israel ''Old Put'' Putnam', 'Old Put', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'
        AND lw.wave_index = 4),
    'A stubborn veteran who holds the line and rallies shaken militia.',
    'Connecticut general famed at Bunker Hill, where legend credits him with the order not to fire until you see the whites of their eyes.',
    'A veteran ranger who left his plow standing in the field when word of Lexington came. At Bunker Hill he helped hold Breed''s Hill and the rail fence, bellowing encouragement through the smoke.

Already a folk legend for crawling into a wolf''s den alone, Old Put embodied the rough courage of the New England militia until a stroke ended his field service in 1779.',
    'hero_old_put_card_16x15', 'hero_details_old_put'
),
(
    '43b37067-8f24-4f3e-ba9b-3c7f10cc629d', 'Henry Knox', 'Colonel Henry Knox', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'Master of artillery whose guns rain down thunderous barrages.',
    'Boston bookseller turned artillery chief who hauled the guns of Ticonderoga three hundred miles through winter to free Boston.',
    'A Boston bookseller who taught himself gunnery from the volumes he sold. In the winter of 1775 he dragged sixty tons of captured Ticonderoga cannon three hundred miles by ox sled to the heights above Boston, forcing the British fleet to sail away.

As chief of artillery he directed the guns at Trenton, Monmouth, and Yorktown, and became the new republic''s first Secretary of War.',
    'hero_henry_knox_card_16x15', 'hero_details_henry_knox'
),
(
    'fac6c094-9cbc-474a-975e-8d2a170e07da', 'George Washington', 'General George Washington', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'The commander-in-chief inspires every soldier fighting near him.',
    'Commander of the Continental Army through eight years of war, from the siege of Boston to the victory at Yorktown.',
    'The Virginia planter who took command of a rabble around Boston in 1775 and, through eight years of defeat, retreat, and privation, never let the Revolution die.

He struck back across the Delaware at Trenton, held the army together at Valley Forge, and trapped Cornwallis at Yorktown. Then, with the war won, he gave his power back and went home.',
    'hero_george_washington_card_16x15', 'hero_details_george_washington'
),
(
    '5c689e4f-5105-4bab-8dd9-63f61124bd35', 'Benedict Arnold', 'Benedict ''Dark Eagle'' Arnold', 'Dark Eagle', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'A fearless battlefield leader who strikes where least expected.',
    'The Revolution''s most gifted field commander at Valcour Island and Saratoga, before his name became a byword for betrayal.',
    'The Revolution''s most dangerous field commander: he stormed Ticonderoga, marched an army through the Maine wilderness to Quebec, delayed a British fleet at Valcour Island, and broke the enemy line at Saratoga, wounded in the same leg twice.

Passed over, indebted, and embittered, he sold West Point to the enemy in 1780, and made his name a synonym for treason.',
    'hero_benedict_arnold_card_16x15', 'hero_details_benedict_arnold'
),
(
    '31f3c69a-094a-4923-8dd0-a7411216d3cb', 'Nathanael Greene', 'Nathanael Greene, the Fighting Quaker', 'The Fighting Quaker', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'A patient strategist who wears the enemy down and never stays beaten.',
    'The Quaker general whose Southern Campaign lost battles but won the war, bleeding Cornwallis all the way to Yorktown.',
    'A self-taught Quaker ironmaster expelled from meeting for drilling with the militia.

After the disaster at Camden he took command of the southern army and waged a masterful campaign of retreat and riposte, declaring he would fight, get beat, rise, and fight again. He bled Cornwallis white at Guilford Courthouse and won back the South without winning a battle.',
    'hero_nathanael_greene_card_16x15', 'hero_details_nathanael_greene'
),
(
    'a72abee1-88a6-4856-a5d4-da460a2233b9', 'Francis Marion', 'Francis Marion, the Swamp Fox', 'The Swamp Fox', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'The Swamp Fox ambushes from the marshes and vanishes without a trace.',
    'South Carolina partisan whose swamp raids kept resistance alive in the occupied South.',
    'A South Carolina partisan who struck from the swamps with a few dozen riders and vanished before the redcoats could form ranks.

From his hidden camp on Snow''s Island he cut supply lines, freed prisoners, and kept resistance alive in an occupied colony. The exasperated British colonel Tarleton gave him his name: that damned old fox.',
    'hero_francis_marion_card_16x15', 'hero_details_francis_marion'
),
(
    'c418c84b-0eb0-46a6-badb-ea0302ca89a7', 'Daniel Morgan', 'Daniel Morgan, the Old Wagoner', 'The Old Wagoner', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'Leads crack riflemen whose aimed fire cuts down officers first.',
    'The Old Wagoner, commander of the rifle corps and architect of the double envelopment at Cowpens.',
    'A backcountry teamster who survived five hundred British lashes and never forgave them.

His Virginia riflemen picked off officers at Quebec and Saratoga, and at Cowpens in 1781 he laid the war''s most perfect trap, using his militia''s weakness as bait to destroy Tarleton''s legion. Gout-ridden and aching, the Old Wagoner won and went home to his farm.',
    'hero_daniel_morgan_card_16x15', 'hero_details_daniel_morgan'
),
(
    '1d9dba5f-e46a-4ca6-ac50-d62b22e7bd1b', 'Friedrich von Steuben', 'Baron von Steuben, the Drillmaster of Valley Forge', 'The Drillmaster of Valley Forge', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'The Prussian drillmaster hardens nearby troops into disciplined regulars.',
    'Prussian officer whose Valley Forge drills and Blue Book turned the Continental Army into a professional force.',
    'A Prussian captain with an inflated resume and a genuine genius for soldiering. Arriving at Valley Forge in 1778 speaking no English, he drilled a model company in person, swearing magnificently in German and French while aides translated.

His Blue Book of regulations turned the Continental Army into a professional force and remained the Army''s manual for decades.',
    'hero_baron_von_steuben_card_16x15', 'hero_details_baron_von_steuben'
),
(
    '4f5ea61b-2be4-46b1-ad0b-21c1a80ab8e4', 'Louis Duportail', 'General Louis Duportail, Father of the Army Corps of Engineers', 'Father of the Army Corps of Engineers', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'Chief engineer whose fieldworks turn any ground into a fortress.',
    'French engineer who became the Continental Army''s chief of engineers and planned the siege works at Yorktown.',
    'A French royal engineer slipped into America in 1777, a year before the alliance was official.

As chief engineer he laid out the defenses at Valley Forge, professionalized the army''s engineering corps, and planned the siege approaches that closed the trap at Yorktown. He returned to France to serve as minister of war in its own revolution.',
    'hero_louis_duportail_card_16x15', 'hero_details_louis_duportail'
),
(
    'ca5f165f-d3e1-44e4-a224-65c8a798c022', 'Mary Hays', 'Mary ''Molly Pitcher'' Hays', 'Molly Pitcher', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'
        AND lw.wave_index = 1),
    'Keeps the guns firing and the soldiers on their feet in the worst of it.',
    'Folk heroine of Monmouth, who carried water to the gun crews and took her fallen husband''s place at the cannon.',
    'At Monmouth, in hundred-degree heat, Mary Hays carried pitcher after pitcher of water to the gun crews while the army''s soldiers cried Molly, pitcher!

When her husband fell at his cannon she stepped into his place and served the piece through the rest of the battle. Pennsylvania later granted her a soldier''s pension for services rendered.',
    'hero_molly_pitcher_card_16x15', 'hero_details_molly_pitcher'
),
(
    'a8c1a230-8fb2-421e-bd22-4aadf6770c3a', 'Horatio Gates', 'Horatio ''Granny'' Gates', 'Granny Gates', (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'
        AND lw.wave_index = 1),
    'A careful organizer whose defenses grind assaults to a halt.',
    'Commanding general at Saratoga, the victory that brought France into the war.',
    'A former British officer who organized the northern army into the force that surrounded Burgoyne at Saratoga, the victory that brought France into the war and the greatest American triumph before Yorktown.

His soldiers called him Granny Gates for his fussing care of them. Camden, in 1780, unmade his reputation as thoroughly as Saratoga had made it.',
    'hero_horatio_gates_card_16x15', 'hero_details_horatio_gates'
),
(
    'dd5b7c53-5f26-4035-aa43-b78b5e177b08', 'William Prescott', 'Colonel William Prescott', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'
        AND lw.wave_index = 1),
    'Holds fortifications long past the point anyone thought possible.',
    'Commander of the redoubt at Bunker Hill, where his militia twice threw back the British regulars before the powder ran out.',
    'The Massachusetts colonel who built the redoubt on Breed''s Hill overnight and commanded it through the battle, walking the parapet in his banyan under naval bombardment to steady his men.

His order to hold fire until the last moment made every round of scarce powder count, and twice threw the regulars back down the hill before the ammunition gave out.',
    'hero_william_prescott_card_16x15', 'hero_details_william_prescott'
),
(
    '4e290eb7-6af2-4e3e-8bd6-ff0759b1b13d', 'Thaddeus Kosciuszko', 'Colonel Thaddeus Kosciuszko', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'
        AND lw.wave_index = 1),
    'A master engineer whose defenses decide battles before they begin.',
    'Polish engineer whose fortifications at Bemis Heights shaped the victory at Saratoga, and who later fortified West Point.',
    'A Polish engineer who offered his sword in 1776 and became the Revolution''s finest military architect.

He chose and fortified Bemis Heights, the ground that made Saratoga unwinnable for Burgoyne, and spent three years building the fortress at West Point. He went home to lead Poland''s own fight for liberty in 1794.',
    'hero_thaddeus_kosciuszko_card_16x15', 'hero_details_thaddeus_kosciuszko'
),
(
    '1feb2d3f-815d-4139-9e47-b99aac112fc8', 'John Glover', 'Brigadier General John Glover', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'
        AND lw.wave_index = 1),
    'His mariners move whole armies across water no one else would cross.',
    'Marblehead fisherman whose amphibious regiment rowed Washington''s army to safety from Long Island and across the Delaware to Trenton.',
    'A Marblehead fisherman whose regiment of mariners saved the Revolution twice: rowing the beaten army off Long Island through fog and darkness without losing a man, and pulling Washington''s assault force through the ice-choked Delaware on Christmas night.

At Pell''s Point his seven hundred delayed four thousand British and Hessians for a full day.',
    'hero_john_glover_card_16x15', 'hero_details_john_glover'
),
(
    '90048c5e-9113-4b6e-987f-047d95f3590a', 'Salem Poor', 'Private Salem Poor', NULL, (SELECT lw.id FROM level_wave lw
       JOIN level_info li ON li.id = lw.level_info_id
       JOIN campaign c ON c.id = li.campaign_id
      WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'
        AND lw.wave_index = 1),
    'A steady soldier whose courage under fire steels those around him.',
    'Formerly enslaved man who bought his freedom, and fought so bravely at Bunker Hill that fourteen officers petitioned to honor him.',
    'Born enslaved in Andover, he purchased his freedom in 1769 for the price of a year''s wages.

At Bunker Hill he fought with such conspicuous courage that fourteen officers petitioned the Massachusetts legislature to honor him as a brave and gallant soldier, a distinction accorded no other man that day. He went on to serve at Valley Forge and White Plains.',
    'hero_salem_poor_card_16x15', 'hero_details_salem_poor'
);
