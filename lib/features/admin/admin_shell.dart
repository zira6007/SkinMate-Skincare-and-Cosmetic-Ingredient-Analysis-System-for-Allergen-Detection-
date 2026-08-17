// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:skin_mate/core/services/auth_service.dart';
//import 'package:skin_mate/core/services/supabase_service.dart';
import 'package:skin_mate/features/admin/users/users_screen.dart';
 import 'package:skin_mate/features/admin/dashboard/dashboard_screen.dart';
 import 'package:skin_mate/features/admin/ingredients/ingredients_screen.dart';
 import 'package:skin_mate/features/admin/products/products_screen.dart';
import 'package:skin_mate/features/admin/feedback/feedback_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {

 
  static const Color _cream       = Color(0xFFF9F3EC);
  static const Color _softBrown   = Color(0xFFB07B6B);
  static const Color _darkBrown   = Color(0xFF4A2C2A);
  static const Color _lightPink   = Color(0xFFF5D5D5);
  static const Color _mutedBrown  = Color(0xFF9A7070);
  static const Color _white       = Color(0xFFFFFFFF);
  static const Color _sidebarBg   = Color(0xFF3D2420); 
  static const Color _sidebarText = Color(0xFFEDD5CC); 
  static const Color _activeItem  = Color(0xFFB07B6B); 

 
  int _selectedIndex = 0;

  
  String _adminName  = 'Admin';
  String _adminEmail = '';
  bool   _loadingProfile = true;


  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

 
  Future<void> _loadAdminProfile() async {
    try {
      final profile = await AuthService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _adminName    = profile['name']  as String? ?? 'Admin';
          _adminEmail   = profile['email'] as String? ?? '';
          _loadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

 
  Future<void> _handleLogout() async {
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log out?',
          style: TextStyle(
            color:      _darkBrown,
            fontWeight: FontWeight.w700,
            fontSize:   16,
          ),
        ),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: _mutedBrown, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
              style: TextStyle(color: _mutedBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _softBrown,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.signOut();
     
    }
  }

 
  static const List<_NavItem> _navItems = [
    _NavItem(
      icon:        Icons.bar_chart_rounded,
      activeIcon:  Icons.bar_chart_rounded,
      label:       'Dashboard',
    ),
    _NavItem(
      icon:        Icons.science_outlined,
      activeIcon:  Icons.science_rounded,
      label:       'Ingredients',
    ),
    _NavItem(
      icon:        Icons.inventory_2_outlined,
      activeIcon:  Icons.inventory_2_rounded,
      label:       'Products',
    ),
    _NavItem(
      icon:        Icons.feedback_outlined,
      activeIcon:  Icons.feedback_rounded,
      label:       'Feedback',
    ),
    _NavItem(
  icon:       Icons.people_outline,
  activeIcon: Icons.people_rounded,
  label:      'Users',
),
  ];

 
  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen(
        );
      case 1:
        return const IngredientsScreen(
        );
      case 2:
        return const ProductsScreen(
        );
      case 3:
        return const FeedbackScreen();
      case 4:
        return const UsersScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Row(
        children: [

          
          _buildSidebar(),

          
          Container(
            width: 1,
            color: _softBrown.withOpacity(0.15),
          ),

          
          Expanded(
            child: Column(
              children: [

                
                _buildTopBar(),

                
                Container(
                  height: 1,
                  color:  _lightPink.withOpacity(0.8),
                ),

                
                Expanded(
                  
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: List.generate(
                      _navItems.length,
                      (i) => _getScreen(i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildSidebar() {
    return Container(
      width:      220,
      height:     double.infinity,
      color:      _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                // Logo circle
                Container(
                  width:  36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:  _activeItem,
                    shape:  BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                        color:      _white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SkinMate',
                      style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      _white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 11,
                        color:    Color(0xFF9A7070),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         _sidebarText.withOpacity(0.35),
                letterSpacing: 0.1,
              ),
            ),
          ),

          
          ...List.generate(_navItems.length, (i) {
            final item       = _navItems[i];
            final isSelected = _selectedIndex == i;
            return _buildNavItem(item, i, isSelected);
          }),

          
          const Spacer(),

          Divider(
            color:  _sidebarText.withOpacity(0.1),
            height: 1,
          ),

          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin:  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color:        isSelected
              ? _activeItem.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: _activeItem.withOpacity(0.3),
                  width: 0.5,
                )
              : null,
        ),
        child: Row(
          children: [

            // Icon
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? _activeItem : _sidebarText.withOpacity(0.55),
              size:  20,
            ),

            const SizedBox(width: 12),

            // Label
            Text(
              item.label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:      isSelected
                    ? _sidebarText
                    : _sidebarText.withOpacity(0.55),
              ),
            ),

            // Active indicator dot
            if (isSelected) ...[
              const Spacer(),
              Container(
                width:  6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _activeItem,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

 
  Widget _buildSidebarFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Admin info row
          Row(
            children: [

              // Avatar circle with first letter of name
              Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:  _activeItem.withOpacity(0.25),
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: _activeItem.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _adminName.isNotEmpty
                        ? _adminName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      _sidebarText,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Name and email
              Expanded(
                child: _loadingProfile
                    ? Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color:        _sidebarText.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _adminName,
                            style: const TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      _sidebarText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _adminEmail,
                            style: TextStyle(
                              fontSize: 10,
                              color:    _sidebarText.withOpacity(0.45),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: Icon(
                Icons.logout_rounded,
                size:  15,
                color: _sidebarText.withOpacity(0.6),
              ),
              label: Text(
                'Log out',
                style: TextStyle(
                  fontSize:   12,
                  color:      _sidebarText.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _sidebarText.withOpacity(0.15),
                  width: 0.8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape:   RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTopBar() {
    return Container(
      height:  60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      color:   _white,
      child: Row(
        children: [

          // Current page title
          Text(
            _navItems[_selectedIndex].label,
            style: const TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w700,
              color:      _darkBrown,
              letterSpacing: -0.3,
            ),
          ),

          const Spacer(),

          // Admin name badge on the right
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color:        _lightPink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width:  22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _softBrown,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _adminName.isNotEmpty
                          ? _adminName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      _white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _adminName,
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      _darkBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}


