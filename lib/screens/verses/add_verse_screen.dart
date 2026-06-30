import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/verse.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/bible_lookup_service.dart';
import '../../services/esv_lookup_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/esv_copyright_footer.dart';
import '../settings/settings_screen.dart';

class AddVerseScreen extends StatefulWidget {
  const AddVerseScreen({
    super.key,
    @visibleForTesting BibleLookupService? lookupService,
    @visibleForTesting EsvLookupService? esvLookupService,
  })  : _lookupServiceOverride = lookupService,
        _esvLookupServiceOverride = esvLookupService;

  final BibleLookupService? _lookupServiceOverride;
  final EsvLookupService? _esvLookupServiceOverride;

  @override
  State<AddVerseScreen> createState() => _AddVerseScreenState();
}

class _AddVerseScreenState extends State<AddVerseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _textController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _previewFocusNode = FocusNode();
  late String _translation;
  bool _isSaving = false;
  bool _isLookingUp = false;
  String? _saveError;
  String? _lookupError;
  String? _capWarning;
  VerseLookupResult? _preview;

  late final _lookupService =
      widget._lookupServiceOverride ?? BibleLookupService();
  late final _esvLookupService =
      widget._esvLookupServiceOverride ?? EsvLookupService();

  static const _consentPrefKey = 'bible_lookup_consent_v1';
  static const _esvConsentPrefKey = 'esv_lookup_consent_v1';
  static const _esvCap = 500;

  @override
  void initState() {
    super.initState();
    final defaultTranslation =
        context.read<SettingsProvider>().settings.defaultTranslation;
    _translation = (defaultTranslation == 'ESV' && !_esvLookupService.isAvailable)
        ? 'BSB'
        : defaultTranslation;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _textController.dispose();
    _searchFocusNode.dispose();
    _previewFocusNode.dispose();
    _lookupService.dispose();
    _esvLookupService.dispose();
    super.dispose();
  }

  Future<bool> _ensureConsentFor({
    required String prefsKey,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) == true) return true;

    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    // Restore focus to Search button after dialog closes.
    _searchFocusNode.requestFocus();
    if (agreed == true) {
      await prefs.setBool(prefsKey, true);
      return true;
    }
    return false;
  }

  Future<bool> _ensureConsent() => _ensureConsentFor(
        prefsKey: _consentPrefKey,
        title: 'Online Verse Lookup',
        body: 'Tapping Search will send the verse reference to bible.helloao.org '
            'over HTTPS to retrieve the text. Your IP address will be visible '
            'to that server. No other data is sent.\n\n'
            'Do you want to continue?',
      );

  Future<bool> _ensureEsvConsent() => _ensureConsentFor(
        prefsKey: _esvConsentPrefKey,
        title: 'ESV Verse Lookup',
        body: 'Tapping Search will send the verse reference to api.esv.org '
            '(Crossway) over HTTPS to retrieve the text. Your IP address will '
            'be visible to that server. No other data is sent.\n\n'
            'ESV lookups are limited to 500 total stored verses by '
            "Crossway's API terms.\n\n"
            'Do you want to continue?',
      );

  Future<void> _lookupVerse() async {
    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      setState(() => _lookupError = 'Enter a reference first.');
      return;
    }

    final isEsv = _translation == 'ESV';

    if (isEsv) {
      final count = context.read<VerseProvider>().esvVerseCount;
      if (count >= _esvCap) {
        setState(() => _capWarning =
            'You have $count ESV verses stored (the maximum). '
            'Delete an ESV verse to add more.');
        return;
      }
    }

    final consented = isEsv ? await _ensureEsvConsent() : await _ensureConsent();
    if (!consented || !mounted) return;

    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _capWarning = null;
      _preview = null;
    });

    try {
      final result = isEsv
          ? await _esvLookupService.lookup(reference)
          : await _lookupService.lookup(reference, _translation);
      if (mounted) {
        setState(() {
          _preview = result;
          _isLookingUp = false;
        });
        _previewFocusNode.requestFocus();
      }
    } on ArgumentError {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Invalid reference format. Try e.g. "Romans 8:28".';
        });
      }
    } on LookupException catch (e) {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = e.message;
        });
      }
    }
  }

  void _acceptPreview() {
    if (_preview == null) return;
    _referenceController.text = _preview!.reference;
    _textController.text = _preview!.text;
    setState(() {
      _translation = _preview!.translation;
      _preview = null;
      _lookupError = null;
    });
    _searchFocusNode.requestFocus();
  }

  void _dismissPreview() {
    setState(() {
      _preview = null;
      _lookupError = null;
    });
    _searchFocusNode.requestFocus();
  }

  Future<void> _saveVerse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_translation == 'ESV') {
      final count = context.read<VerseProvider>().esvVerseCount;
      if (count >= _esvCap) {
        setState(() => _saveError =
            'ESV storage limit reached ($count/$_esvCap). Delete an ESV verse to add more.');
        return;
      }
    }

    setState(() => _isSaving = true);

    final reference = _referenceController.text.trim();
    final text = _textController.text.trim();

    final id =
        '${_translation.toLowerCase()}_${reference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    final verse = Verse(
      id: id,
      reference: reference,
      text: text,
      translation: _translation,
      packId: 'custom',
      addedAt: DateTime.now(),
    );

    try {
      await context.read<VerseProvider>().addCustomVerse(verse);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Failed to save verse. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Verse'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference e.g. Romans 8:28',
                    ),
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reference is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  focusNode: _searchFocusNode,
                  onPressed: (_isLookingUp || _isSaving) ? null : _lookupVerse,
                  child: _isLookingUp
                      ? Semantics(
                          liveRegion: true,
                          label: 'Looking up verse, please wait',
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            // Semantics node always in tree so liveRegion fires on label change.
            Semantics(
              liveRegion: true,
              label: _lookupError ?? '',
              child: _lookupError != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Symbols.error_rounded, size: 16, color: cs.error),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _lookupError!,
                              style: tt.bodyMedium?.copyWith(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Semantics node always in tree so liveRegion fires on label change.
            Semantics(
              liveRegion: true,
              label: _capWarning ?? '',
              child: _capWarning != null
                  ? Card(
                      color: cs.warningContainer,
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Symbols.warning_rounded,
                                size: 16, color: cs.onWarningContainer),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _capWarning!,
                                style: tt.bodyMedium
                                    ?.copyWith(color: cs.onWarningContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 12),
              Semantics(
                label: 'Verse preview: ${_preview!.reference} ${_preview!.translation}. '
                    '${_preview!.text}. Use Accept or Dismiss buttons below.',
                focusable: true,
                child: Focus(
                  focusNode: _previewFocusNode,
                  child: Card(
                    color: cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_preview!.reference} (${_preview!.translation})',
                            style: tt.labelLarge
                                ?.copyWith(color: cs.onSecondaryContainer),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _preview!.text,
                            style: tt.bodyLarge
                                ?.copyWith(color: cs.onSecondaryContainer),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.tonal(
                                onPressed: _acceptPreview,
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _dismissPreview,
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Verse text',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Verse text is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ExcludeSemantics(
              child: Text(
                'Translation',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Translation',
              container: true,
              child: SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'BSB', label: Text('BSB')),
                  const ButtonSegment(value: 'KJV', label: Text('KJV')),
                  const ButtonSegment(value: 'WEB', label: Text('WEB')),
                  if (_esvLookupService.isAvailable)
                    const ButtonSegment(value: 'ESV', label: Text('ESV')),
                ],
                selected: {_translation},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) {
                    setState(() {
                      _translation = values.first;
                      _capWarning = null;
                    });
                  }
                },
              ),
            ),
            if (_esvLookupService.isAvailable && _translation == 'ESV') ...[
              const SizedBox(height: 8),
              Text(
                'ESV · Personal use · 500-verse cap',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 32),
            // Semantics node always in tree so liveRegion fires on label change.
            Semantics(
              liveRegion: true,
              label: _saveError ?? '',
              child: _saveError != null
                  ? Card(
                      color: cs.errorContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Symbols.error_rounded,
                                size: 16, color: cs.onErrorContainer),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _saveError!,
                                style: tt.bodyMedium
                                    ?.copyWith(color: cs.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _saveVerse,
              child: _isSaving
                  ? Semantics(
                      liveRegion: true,
                      label: 'Saving, please wait',
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      ),
                    )
                  : const Text('Save Verse'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            EsvCopyrightFooter(
              hasEsvContent: _translation == 'ESV' && _preview != null,
              onViewFullTerms: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
