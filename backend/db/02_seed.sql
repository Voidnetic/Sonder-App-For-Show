-- Demo data mirroring the Flutter app's mock data (lib/data/mock_data.dart).
-- Every demo account's password is: sonderpass123

INSERT INTO users (id, name, email, password_hash, avatar_color) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Hassan', 'hassan@sonder.app', '$2b$12$n8a4LQzpayxTKs0Llu8MFeclV.ImC2JUfzwMrh.Ha3dqjpc7Vy9ii', '#FFFACD'),
    ('00000000-0000-0000-0000-000000000002', 'Ali',    'ali@sonder.app',    '$2b$12$n8a4LQzpayxTKs0Llu8MFeclV.ImC2JUfzwMrh.Ha3dqjpc7Vy9ii', '#E6E6FA'),
    ('00000000-0000-0000-0000-000000000003', 'Ahmed',  'ahmed@sonder.app',  '$2b$12$n8a4LQzpayxTKs0Llu8MFeclV.ImC2JUfzwMrh.Ha3dqjpc7Vy9ii', '#E0F8E6'),
    ('00000000-0000-0000-0000-000000000004', 'Hajra',  'hajra@sonder.app',  '$2b$12$n8a4LQzpayxTKs0Llu8MFeclV.ImC2JUfzwMrh.Ha3dqjpc7Vy9ii', '#FFD9C0'),
    ('00000000-0000-0000-0000-000000000005', 'Manaal', 'manaal@sonder.app', '$2b$12$n8a4LQzpayxTKs0Llu8MFeclV.ImC2JUfzwMrh.Ha3dqjpc7Vy9ii', '#E6E6FA')
ON CONFLICT DO NOTHING;

INSERT INTO friendships (requester_id, recipient_id, status) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'accepted'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'accepted'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'accepted'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'accepted')
ON CONFLICT DO NOTHING;

-- Two active (still locked) moments and one already-unlocked moment for the archive screen.
INSERT INTO moments (id, title, creator_id, accent_color, unlock_at, revealed_at) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Birthday Night', '00000000-0000-0000-0000-000000000001', '#E6E6FA',
        now() + interval '2 hours 14 minutes', NULL),
    ('10000000-0000-0000-0000-000000000002', 'Murree Trip', '00000000-0000-0000-0000-000000000001', '#E0F8E6',
        now() + interval '1 day', NULL),
    ('10000000-0000-0000-0000-000000000003', 'University Farewell', '00000000-0000-0000-0000-000000000001', '#FFFACD',
        now() - interval '7 days', now() - interval '7 days'),
    -- Unlocked but not revealed yet, so the reveal can be shown straight away.
    ('10000000-0000-0000-0000-000000000004', 'Summer Beach Trip', '00000000-0000-0000-0000-000000000001', '#E1F5FE',
        now() - interval '1 hour', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO moment_participants (moment_id, user_id) VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005')
ON CONFLICT DO NOTHING;

-- Demo photos (files in backend/uploads/demo-*.jpg). Birthday Night's stay hidden until it unlocks.
INSERT INTO memories (id, moment_id, author_id, image_url, caption, captured_at) VALUES
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '/uploads/demo-1.jpg', NULL, now() - interval '30 minutes'),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '/uploads/demo-2.jpg', NULL, now() - interval '20 minutes'),
    ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', '/uploads/demo-3.jpg', NULL, now() - interval '10 minutes'),
    ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '/uploads/demo-4.jpg', 'First swim', now() - interval '6 hours'),
    ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '/uploads/demo-5.jpg', NULL, now() - interval '4 hours'),
    ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005', '/uploads/demo-6.jpg', 'Ice cream run', now() - interval '3 hours'),
    ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '/uploads/demo-7.jpg', NULL, now() - interval '2 hours'),
    ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', '/uploads/demo-8.jpg', NULL, now() - interval '8 days'),
    ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005', '/uploads/demo-9.jpg', 'Last day!', now() - interval '8 days')
ON CONFLICT DO NOTHING;

-- Hangout chat for Birthday Night, matching the conversation shown in active_moment_screen.dart.
INSERT INTO messages (moment_id, author_id, type, text, created_at)
SELECT v.moment_id::uuid, v.author_id::uuid, v.type::message_type, v.text, now() - v.ago
FROM (VALUES
    ('10000000-0000-0000-0000-000000000001', NULL, 'system', 'Ali joined the Moment', interval '10 minutes'),
    ('10000000-0000-0000-0000-000000000001', NULL, 'system', 'Hajra joined the Moment', interval '9 minutes'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'user', 'Where are you guys?', interval '8 minutes'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'user', 'We''re outside 😂', interval '7 minutes'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'user', 'Cominggg', interval '5 minutes'),
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'user', 'Someone save me food', interval '4 minutes')
) AS v (moment_id, author_id, type, text, ago)
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE moment_id = '10000000-0000-0000-0000-000000000001');
