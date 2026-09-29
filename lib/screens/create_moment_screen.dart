import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'active_moment_screen.dart';

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final TextEditingController _titleController = TextEditingController();
  final List<String> _selectedFriends = [];
  String _selectedTime = "Tonight";
  bool _isButtonPressed = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.kBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create a memory",
          style: TextStyle(
            color: AppTheme.kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("MOMENT NAME", style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [BoxShadow(color: AppTheme.kLavender, offset: Offset(4, 4))],
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "e.g. Birthday Night",
                  hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text("WHO IS COMING?", style: _sectionTitleStyle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: MockData.friends.map((friend) {
                final isSelected = _selectedFriends.contains(friend);
                return _buildBouncyFriendChip(friend, isSelected);
              }).toList(),
            ),
            const SizedBox(height: 40),
            const Text("WHEN SHOULD IT REVEAL?", style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Row(
              children: ["Tonight", "Tomorrow", "Custom"].map((time) {
                final isSelected = _selectedTime == time;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTime = time),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.kPaleYellow : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.kBorder, width: 2),
                        boxShadow: isSelected 
                            ? const [BoxShadow(color: AppTheme.kBorder, offset: Offset(2, 2))]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          time,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: AppTheme.kTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 60),

            // CREATE BUTTON
            GestureDetector(
              onTapDown: (_) => setState(() => _isButtonPressed = true),
              onTapUp: (_) {
                setState(() => _isButtonPressed = false);

                // 1. Grab title or fallback to default
                final titleText = _titleController.text.trim().isEmpty 
                    ? "Unnamed Moment" 
                    : _titleController.text.trim();

                // 2. Create and insert the new moment into MockData
                final newMoment = Moment(
                  title: titleText,
                  memoryCount: 0,
                  friendCount: _selectedFriends.isEmpty ? 1 : _selectedFriends.length,
                  unlockText: _selectedTime == "Tonight" ? "04 : 00 : 00" : "tomorrow",
                  accentColor: AppTheme.kPalePeach,
                );
                MockData.addMoment(newMoment);

                // 3. Navigate to active view passing the new moment
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ActiveMomentScreen(moment: newMoment)),
                );
              },
              onTapCancel: () => setState(() => _isButtonPressed = false),
              child: AnimatedScale(
                scale: _isButtonPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.kTextPrimary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                    boxShadow: _isButtonPressed
                        ? []
                        : const [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(6, 6))],
                  ),
                  child: const Center(
                    child: Text(
                      "CREATE MOMENT",
                      style: TextStyle(
                        color: AppTheme.kBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBouncyFriendChip(String name, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? _selectedFriends.remove(name) : _selectedFriends.add(name);
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.kTextPrimary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: isSelected 
                ? const [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(4, 4))] 
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.white : AppTheme.kTextSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.kTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _sectionTitleStyle = TextStyle(
    color: AppTheme.kTextSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
}