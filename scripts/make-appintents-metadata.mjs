// Writes Contents/Resources/Metadata.appintents into the widget appex.
//
// Xcode produces this with appintentsmetadataprocessor, which ships only with
// the full IDE. Without it a WidgetConfigurationIntent has no metadata, so
// WidgetKit renders an empty Edit sheet and the widget's own colour picker does
// not exist. The format is plain JSON; the shapes below were read off Apple's
// own widget extensions, and every type is referenced by its Swift mangled
// name, verified with `xcrun swift-demangle`.
//
// usage: node scripts/make-appintents-metadata.mjs <path-to-appex>
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const appex = process.argv[2];
if (!appex) {
  console.error('usage: make-appintents-metadata.mjs <path-to-appex>');
  process.exit(2);
}

const anywhere = { LNPlatformNameWildcard: { introducedVersion: '*' } };
const text = (key) => ({ alternatives: [], key });

/** A Bool parameter. typeIdentifier 1 is what every system toggle uses. */
const boolParameter = (name, title) => ({
  capabilities: 0,
  dynamicOptionsSupport: 0,
  inputConnectionBehavior: 0,
  isInput: false,
  isOptional: false,
  name,
  resolvableInputTypes: [],
  title: text(title),
  typeSpecificMetadata: [],
  valueType: { primitive: { wrapper: { typeIdentifier: 1 } } },
});

/** A parameter whose values come from an AppEnum. */
const enumParameter = (name, title, enumIdentifier) => ({
  capabilities: 0,
  dynamicOptionsSupport: 0,
  inputConnectionBehavior: 0,
  isInput: false,
  isOptional: false,
  name,
  resolvableInputTypes: [],
  title: text(title),
  typeSpecificMetadata: [],
  valueType: { linkEnumeration: { wrapper: { identifier: enumIdentifier } } },
});

const appEnum = ({ identifier, module, mangledTypeName, displayName, cases }) => ({
  assistantDefinedSchemas: [],
  availabilityAnnotations: anywhere,
  cases: cases.map(([id, title]) => ({
    displayRepresentation: { title: text(title) },
    identifier: id,
  })),
  displayTypeName: text(displayName),
  effectiveBundleIdentifiers: [],
  fullyQualifiedTypeName: `${module}.${identifier}`,
  identifier,
  isSystem: false,
  mangledTypeName,
  mangledTypeNameByBundleIdentifier: {},
  visibilityMetadata: { assistantOnly: false, isDiscoverable: true },
});

const metadata = {
  actions: {
    ClockConfiguration: {
      assistantDefinedSchemas: [],
      assistantDefinedSchemaTraits: [],
      authenticationPolicy: 0,
      availabilityAnnotations: anywhere,
      effectiveBundleIdentifiers: [],
      fullyQualifiedTypeName: 'ClockWidget.ClockConfiguration',
      identifier: 'ClockConfiguration',
      isAuthPolExplicit: false,
      isDiscoverable: false,
      mangledTypeName: '11ClockWidget18ClockConfigurationV',
      mangledTypeNameByBundleIdentifier: {},
      mangledTypeNameByBundleIdentifierV2: {},
      mangledTypeNameV2: '11ClockWidget18ClockConfigurationV',
      openAppWhenRun: false,
      outputFlags: 8,
      parameters: [
        enumParameter('skin', 'Colour', 'ClockSkin'),
        boolParameter('neon', 'Neon glow'),
        boolParameter('pulse', 'Pulse the glow'),
        enumParameter('hourFormat', 'Hours', 'ClockHourFormat'),
      ],
      presentationStyle: 0,
      requiredCapabilities: [],
      supportedModes: 1,
      systemProtocolMetadata: [
        'com.apple.link.systemProtocol.WidgetConfiguration',
        { empty: {} },
      ],
      systemProtocolMetadataV2: [
        'com.apple.link.systemProtocol.WidgetConfiguration',
        { empty: {} },
      ],
      systemProtocols: ['com.apple.link.systemProtocol.WidgetConfiguration'],
      title: text('Clock'),
      typeSpecificMetadata: [],
      visibilityMetadata: { assistantOnly: false, isDiscoverable: true },
    },
  },
  assistantEntities: [],
  assistantIntentNegativePhrases: [],
  assistantIntents: [],
  autoShortcuts: [],
  entities: {},
  enums: [
    appEnum({
      identifier: 'ClockSkin',
      module: 'ClockCore',
      mangledTypeName: '9ClockCore9ClockSkinO',
      displayName: 'Colour',
      cases: [
        ['red', 'Imperator Red'],
        ['green', 'Arcade Green'],
        ['blue', 'Neon Blue'],
        ['white', 'Classic White'],
        ['purple', 'Electric Purple'],
        ['custom', 'Custom'],
      ],
    }),
    appEnum({
      identifier: 'ClockHourFormat',
      module: 'ClockCore',
      mangledTypeName: '9ClockCore15ClockHourFormatO',
      displayName: 'Hours',
      cases: [
        ['system', 'System'],
        ['twentyFour', '24-hour'],
        ['twelve', '12-hour'],
      ],
    }),
  ],
  generator: { name: 'xcode-tools', version: '17E6107' },
  negativePhrases: [],
  queries: {},
  shortcutTileColor: 14,
  version: 1,
};

const dir = join(appex, 'Contents/Resources/Metadata.appintents');
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, 'extract.actionsdata'), JSON.stringify(metadata));
writeFileSync(
  join(dir, 'version.json'),
  JSON.stringify({ toolsVersion: '17E6107', version: '3.0' }, null, 2)
);
console.log(`APPINTENTS_METADATA_OK ${dir}`);
