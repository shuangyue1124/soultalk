// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ApiConfig _$ApiConfigFromJson(Map<String, dynamic> json) {
  return _ApiConfig.fromJson(json);
}

/// @nodoc
mixin _$ApiConfig {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  LlmProvider get provider => throw _privateConstructorUsedError;
  String get baseUrl => throw _privateConstructorUsedError;
  String get apiKey => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  int get maxTokens => throw _privateConstructorUsedError;
  double get temperature => throw _privateConstructorUsedError;
  bool get streamEnabled => throw _privateConstructorUsedError;
  bool get thinkingEnabled => throw _privateConstructorUsedError;
  String get reasoningEffort => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ApiConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApiConfigCopyWith<ApiConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApiConfigCopyWith<$Res> {
  factory $ApiConfigCopyWith(ApiConfig value, $Res Function(ApiConfig) then) =
      _$ApiConfigCopyWithImpl<$Res, ApiConfig>;
  @useResult
  $Res call({
    String id,
    String name,
    LlmProvider provider,
    String baseUrl,
    String apiKey,
    String model,
    int maxTokens,
    double temperature,
    bool streamEnabled,
    bool thinkingEnabled,
    String reasoningEffort,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$ApiConfigCopyWithImpl<$Res, $Val extends ApiConfig>
    implements $ApiConfigCopyWith<$Res> {
  _$ApiConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? provider = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? model = null,
    Object? maxTokens = null,
    Object? temperature = null,
    Object? streamEnabled = null,
    Object? thinkingEnabled = null,
    Object? reasoningEffort = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            provider: null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as LlmProvider,
            baseUrl: null == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            apiKey: null == apiKey
                ? _value.apiKey
                : apiKey // ignore: cast_nullable_to_non_nullable
                      as String,
            model: null == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String,
            maxTokens: null == maxTokens
                ? _value.maxTokens
                : maxTokens // ignore: cast_nullable_to_non_nullable
                      as int,
            temperature: null == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double,
            streamEnabled: null == streamEnabled
                ? _value.streamEnabled
                : streamEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            thinkingEnabled: null == thinkingEnabled
                ? _value.thinkingEnabled
                : thinkingEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            reasoningEffort: null == reasoningEffort
                ? _value.reasoningEffort
                : reasoningEffort // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ApiConfigImplCopyWith<$Res>
    implements $ApiConfigCopyWith<$Res> {
  factory _$$ApiConfigImplCopyWith(
    _$ApiConfigImpl value,
    $Res Function(_$ApiConfigImpl) then,
  ) = __$$ApiConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    LlmProvider provider,
    String baseUrl,
    String apiKey,
    String model,
    int maxTokens,
    double temperature,
    bool streamEnabled,
    bool thinkingEnabled,
    String reasoningEffort,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ApiConfigImplCopyWithImpl<$Res>
    extends _$ApiConfigCopyWithImpl<$Res, _$ApiConfigImpl>
    implements _$$ApiConfigImplCopyWith<$Res> {
  __$$ApiConfigImplCopyWithImpl(
    _$ApiConfigImpl _value,
    $Res Function(_$ApiConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? provider = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? model = null,
    Object? maxTokens = null,
    Object? temperature = null,
    Object? streamEnabled = null,
    Object? thinkingEnabled = null,
    Object? reasoningEffort = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ApiConfigImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as LlmProvider,
        baseUrl: null == baseUrl
            ? _value.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        apiKey: null == apiKey
            ? _value.apiKey
            : apiKey // ignore: cast_nullable_to_non_nullable
                  as String,
        model: null == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String,
        maxTokens: null == maxTokens
            ? _value.maxTokens
            : maxTokens // ignore: cast_nullable_to_non_nullable
                  as int,
        temperature: null == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double,
        streamEnabled: null == streamEnabled
            ? _value.streamEnabled
            : streamEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        thinkingEnabled: null == thinkingEnabled
            ? _value.thinkingEnabled
            : thinkingEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        reasoningEffort: null == reasoningEffort
            ? _value.reasoningEffort
            : reasoningEffort // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApiConfigImpl implements _ApiConfig {
  const _$ApiConfigImpl({
    required this.id,
    required this.name,
    this.provider = LlmProvider.openai,
    required this.baseUrl,
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.maxTokens = 4096,
    this.temperature = 0.8,
    this.streamEnabled = true,
    this.thinkingEnabled = false,
    this.reasoningEffort = 'high',
    this.createdAt,
    this.updatedAt,
  });

  factory _$ApiConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApiConfigImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey()
  final LlmProvider provider;
  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  @JsonKey()
  final String model;
  @override
  @JsonKey()
  final int maxTokens;
  @override
  @JsonKey()
  final double temperature;
  @override
  @JsonKey()
  final bool streamEnabled;
  @override
  @JsonKey()
  final bool thinkingEnabled;
  @override
  @JsonKey()
  final String reasoningEffort;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ApiConfig(id: $id, name: $name, provider: $provider, baseUrl: $baseUrl, apiKey: $apiKey, model: $model, maxTokens: $maxTokens, temperature: $temperature, streamEnabled: $streamEnabled, thinkingEnabled: $thinkingEnabled, reasoningEffort: $reasoningEffort, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApiConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.maxTokens, maxTokens) ||
                other.maxTokens == maxTokens) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.streamEnabled, streamEnabled) ||
                other.streamEnabled == streamEnabled) &&
            (identical(other.thinkingEnabled, thinkingEnabled) ||
                other.thinkingEnabled == thinkingEnabled) &&
            (identical(other.reasoningEffort, reasoningEffort) ||
                other.reasoningEffort == reasoningEffort) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    provider,
    baseUrl,
    apiKey,
    model,
    maxTokens,
    temperature,
    streamEnabled,
    thinkingEnabled,
    reasoningEffort,
    createdAt,
    updatedAt,
  );

  /// Create a copy of ApiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApiConfigImplCopyWith<_$ApiConfigImpl> get copyWith =>
      __$$ApiConfigImplCopyWithImpl<_$ApiConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ApiConfigImplToJson(this);
  }
}

abstract class _ApiConfig implements ApiConfig {
  const factory _ApiConfig({
    required final String id,
    required final String name,
    final LlmProvider provider,
    required final String baseUrl,
    required final String apiKey,
    final String model,
    final int maxTokens,
    final double temperature,
    final bool streamEnabled,
    final bool thinkingEnabled,
    final String reasoningEffort,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ApiConfigImpl;

  factory _ApiConfig.fromJson(Map<String, dynamic> json) =
      _$ApiConfigImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  LlmProvider get provider;
  @override
  String get baseUrl;
  @override
  String get apiKey;
  @override
  String get model;
  @override
  int get maxTokens;
  @override
  double get temperature;
  @override
  bool get streamEnabled;
  @override
  bool get thinkingEnabled;
  @override
  String get reasoningEffort;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of ApiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApiConfigImplCopyWith<_$ApiConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
