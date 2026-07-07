import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database_helper.dart';
import '../../models/verse.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/bible_lookup_service.dart';
import '../../services/esv_lookup_service.dart';
import '../../utils/reference_normalization.dart';
import '../../widgets/esv_copyright_footer.dart';
import '../../widgets/inline_status_banner.dart';
import '../settings/book_variants_screen.dart';
import '../settings/settings_screen.dart';

class AddVerseScreen extends StatefulWidget {
  const AddVerseScreen({
    super.key,
    @visibleForTesting BibleLookupService? lookupService,
    @visibleForTesting EsvLookupService? esvLookupService,
    @visibleForTesting
    Future<Map<String, String>> Function()? customVariantLookup,
  })  : _lookupServiceOverride = lookupService,
        _esvLookupServiceOverride = esvLookupService,
        _customVariantLookupOverride = customVariantLookup;

  final BibleLookupService? _lookupServiceOverride;
  final EsvLookupService? _esvLookupServiceOverride;
  final Future<Map<String, String>> Function()? _customVariantLookupOverride;

  @override
  State<AddVerseScreen> createState() => _AddVerseScreenState();
}

class _AddVerseScreenState extends State<AddVerseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _textController = TextEditingController();
  final _referenceFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _saveFocusNode = FocusNode();
  late String _translation;
  bool _isSaving = false;
  bool _isLookingUp = false;
  String? _saveError;
  String? _lookupError;
  String? _capWarning;
  String? _referenceFieldError;
  bool _referenceUnresolved = false;
  bool _saveAsMemorized = false;
  bool _saveAndAddMore = false;
  Future<({String? reference, bool unresolved})>? _pendingResolutionFuture;
  String? _pendingResolutionInput;

  late final _lookupService =
      widget._lookupServiceOverride ?? BibleLookupService();
  late final _esvLookupService =
      widget._esvLookupServiceOverride ?? EsvLookupService();
  late final _customVariantLookup = widget._customVariantLookupOverride ??
      DatabaseHelper().getCustomVariantLookup;

  static const _consentPrefKey = 'bible_lookup_consent_v1';
  static const _esvConsentPrefKey = 'esv_lookup_consent_v1';
  static const _esvCap = 500;

  static const _invalidFormatMessage =
      'Invalid reference format. Try e.g. "Romans 8:28".';
  static const _unresolvedBookMessage =
      'Unrecognized book name. Add a custom variant in Book Name '
      'Variants settings, or fix the spelling.';
  static const _unresolvedBookFieldError = 'Unrecognized book name';

  @override
  void initState() {
    super.initState();
    final defaultTranslation =
        context.read<SettingsProvider>().settings.defaultTranslation;
    _translation = (defaultTranslation == 'ESV' && !_esvLookupService.isAvailable)
        ? 'BSB'
        : defaultTranslation;
    _referenceController.addListener(_onReferenceEdited);
    _referenceFocusNode.addListener(_onReferenceFocusChange);
  }

  void _onReferenceFocusChange() {
    if (_referenceFocusNode.hasFocus) return;
    _normalizeReferenceOnBlur();
  }

  /// Normalizes the reference field as soon as the user tabs/taps away from
  /// it, so the resolved form (or an unrecognized-book error) is visible
  /// immediately rather than only surfacing at save time. Does not reclaim
  /// focus on failure — the user is deliberately moving on to another field.
  Future<void> _normalizeReferenceOnBlur() async {
    final raw = _referenceController.text.trim();
    if (raw.isEmpty) return;

    final resolution = await _resolveReferenceDeduped(raw);
    if (!mounted) return;

    if (resolution.reference == null) {
      setState(() {
        _referenceUnresolved = resolution.unresolved;
        _referenceFieldError = resolution.unresolved
            ? _unresolvedBookFieldError
            : _invalidFormatMessage;
      });
      _formKey.currentState?.validate();
      return;
    }

    if (resolution.reference != raw) {
      _referenceController.text = resolution.reference!;
    }
    setState(() {
      _referenceFieldError = null;
      _referenceUnresolved = false;
    });
  }

  void _onReferenceEdited() {
    if (_referenceFieldError != null || _referenceUnresolved) {
      setState(() {
        _referenceFieldError = null;
        _referenceUnresolved = false;
      });
    }
  }

  @override
  void dispose() {
    _referenceController.removeListener(_onReferenceEdited);
    _referenceController.dispose();
    _textController.dispose();
    _referenceFocusNode.dispose();
    _searchFocusNode.dispose();
    _saveFocusNode.dispose();
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

  /// Fetches custom book-name variants (falling back to built-in resolution
  /// only if that read fails) and normalizes [rawReference] against them.
  /// Returns the resolved reference, or null with [unresolved] set if the
  /// failure was specifically an unrecognized book name (as opposed to a
  /// malformed reference), so callers can show the same "Open Book Name
  /// Variants settings" shortcut regardless of which flow triggered it.
  Future<({String? reference, bool unresolved})> _resolveReference(
    String rawReference,
  ) async {
    var customVariants = const <String, String>{};
    try {
      customVariants = await _customVariantLookup();
    } catch (_) {
      // Fall through with no custom variants; built-in resolution still applies.
    }

    final result = normalizeReferenceForSave(
      rawReference,
      customVariants: customVariants,
    );
    if (!result.isSuccess) {
      return (
        reference: null,
        unresolved:
            result.failure == ReferenceNormalizationFailure.unresolvedBook,
      );
    }
    return (reference: result.reference, unresolved: false);
  }

  /// Reuses an in-flight [_resolveReference] call for the same [rawReference]
  /// instead of starting a second one. Blurring the reference field (to
  /// normalize it inline) and tapping Save both resolve the same text at
  /// nearly the same moment when Save is tapped right after an edit; without
  /// this, both would independently hit the database.
  Future<({String? reference, bool unresolved})> _resolveReferenceDeduped(
    String rawReference,
  ) {
    if (_pendingResolutionInput == rawReference &&
        _pendingResolutionFuture != null) {
      return _pendingResolutionFuture!;
    }

    final future = _resolveReference(rawReference);
    _pendingResolutionInput = rawReference;
    _pendingResolutionFuture = future;
    future.whenComplete(() {
      if (identical(_pendingResolutionFuture, future)) {
        _pendingResolutionFuture = null;
        _pendingResolutionInput = null;
      }
    });
    return future;
  }

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
    });

    final resolution = await _resolveReference(reference);
    if (!mounted) return;

    if (resolution.reference == null) {
      setState(() {
        _isLookingUp = false;
        _referenceUnresolved = resolution.unresolved;
        _lookupError =
            resolution.unresolved ? _unresolvedBookMessage : _invalidFormatMessage;
      });
      return;
    }
    final resolvedReference = resolution.reference!;

    try {
      final result = isEsv
          ? await _esvLookupService.lookup(resolvedReference)
          : await _lookupService.lookup(resolvedReference, _translation);
      if (mounted) {
        _referenceController.text = result.reference;
        _textController.text = result.text;
        setState(() {
          _translation = result.translation;
          _isLookingUp = false;
        });
        _searchFocusNode.requestFocus();
      }
    } on ArgumentError {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = _invalidFormatMessage;
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

    final resolution =
        await _resolveReferenceDeduped(_referenceController.text.trim());
    if (!mounted) return;

    if (resolution.reference == null) {
      setState(() {
        _isSaving = false;
        _referenceUnresolved = resolution.unresolved;
        _referenceFieldError = resolution.unresolved
            ? _unresolvedBookFieldError
            : _invalidFormatMessage;
        _saveError = resolution.unresolved
            ? _unresolvedBookMessage
            : _invalidFormatMessage;
      });
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _isSaving = false;
      _referenceFieldError = null;
      _referenceUnresolved = false;
      _saveError = null;
    });

    final reference = resolution.reference!;
    final confirmed = await _showSaveConfirmationDialog(reference);
    if (!mounted) return;
    // Restore focus to Save (the control that opened this dialog), same
    // pattern as the ESV consent dialog restoring focus to Search.
    _saveFocusNode.requestFocus();
    if (confirmed != true) return;

    await _commitSave(reference);
  }

  Future<bool?> _showSaveConfirmationDialog(String reference) {
    final tt = Theme.of(context).textTheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this verse?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reference, style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(_textController.text.trim()),
              const SizedBox(height: 8),
              Text(
                'Will be saved to: ${_saveAsMemorized ? 'Memorized' : 'Available'}',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('add-verse-confirm-save-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_saveAndAddMore ? 'Save and add more' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _commitSave(String reference) async {
    setState(() => _isSaving = true);

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
      isMemorized: _saveAsMemorized,
      memorizedAt: _saveAsMemorized ? DateTime.now() : null,
    );

    try {
      await context.read<VerseProvider>().addCustomVerse(verse);
      if (!mounted) return;
      if (_saveAndAddMore) {
        _resetFormForAnotherVerse();
      } else {
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

  /// Clears the form back to a blank state after a "Save and add more" save,
  /// keeping the "Save and add more" checkbox checked for repeated entry.
  void _resetFormForAnotherVerse() {
    final defaultTranslation =
        context.read<SettingsProvider>().settings.defaultTranslation;
    _referenceController.clear();
    _textController.clear();
    setState(() {
      _isSaving = false;
      _translation = (defaultTranslation == 'ESV' && !_esvLookupService.isAvailable)
          ? 'BSB'
          : defaultTranslation;
      _saveAsMemorized = false;
      _saveError = null;
      _lookupError = null;
      _capWarning = null;
      _referenceFieldError = null;
      _referenceUnresolved = false;
    });
    _referenceFocusNode.requestFocus();
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
                    key: const Key('add-verse-reference-field'),
                    controller: _referenceController,
                    focusNode: _referenceFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Reference e.g. Romans 8:28',
                    ),
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reference is required';
                      }
                      return _referenceFieldError;
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
            InlineStatusBanner(
              severity: BannerSeverity.error,
              message: _lookupError,
              filled: false,
            ),
            InlineStatusBanner(
              severity: BannerSeverity.warning,
              message: _capWarning,
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: const Key('add-verse-text-field'),
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
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saveAsMemorized,
              title: const Text('Add directly to Memorized'),
              onChanged: (value) =>
                  setState(() => _saveAsMemorized = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saveAndAddMore,
              title: const Text('Save and add more'),
              onChanged: (value) =>
                  setState(() => _saveAndAddMore = value ?? false),
            ),
            const SizedBox(height: 24),
            InlineStatusBanner(
              severity: BannerSeverity.error,
              message: _saveError,
            ),
            if (_referenceUnresolved)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BookVariantsScreen(),
                    ),
                  ),
                  child: const Text('Open Book Name Variants settings'),
                ),
              ),
            FilledButton(
              key: const Key('add-verse-save-button'),
              focusNode: _saveFocusNode,
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
              hasEsvContent: _translation == 'ESV',
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
