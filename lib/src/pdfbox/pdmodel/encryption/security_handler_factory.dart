import 'protection_policy.dart';
import 'security_handler.dart';
import 'standard_protection_policy.dart';
import 'standard_security_handler.dart';

typedef _FilterFactory = SecurityHandler<ProtectionPolicy> Function();
typedef _PolicyFactory = SecurityHandler<ProtectionPolicy> Function(
    ProtectionPolicy policy);

Type _typeOf<T>() => T;

/// Registry of available security handlers mirroring the factory present in
/// Apache PDFBox.
class SecurityHandlerFactory {
  SecurityHandlerFactory._() {
    registerHandler<StandardProtectionPolicy>(
      filter: StandardSecurityHandler.filter,
      filterCreator: () => StandardSecurityHandler(),
      policyCreator: (policy) => StandardSecurityHandler(policy),
    );
  }

  static final SecurityHandlerFactory instance = SecurityHandlerFactory._();

  final Map<String, _FilterFactory> _filterFactories =
      <String, _FilterFactory>{};
  final Map<Type, _PolicyFactory> _policyFactories = <Type, _PolicyFactory>{};

  /// Registers a security handler implementation for both filter based lookup
  /// and protection policy construction. Attempts to re-register the same
  /// filter or policy type will throw to mirror the behaviour of the Java
  /// implementation.
  void registerHandler<T extends ProtectionPolicy>({
    required String filter,
    required SecurityHandler<ProtectionPolicy> Function() filterCreator,
    required SecurityHandler<ProtectionPolicy> Function(T policy) policyCreator,
  }) {
    if (_filterFactories.containsKey(filter)) {
      throw StateError(
          'The security handler filter "$filter" is already registered');
    }
    final policyType = _typeOf<T>();
    if (_policyFactories.containsKey(policyType)) {
      throw StateError(
          'A handler for policy type $policyType is already registered');
    }
    _filterFactories[filter] = filterCreator;
    _policyFactories[policyType] = (ProtectionPolicy policy) {
      if (policy is! T) {
        throw ArgumentError.value(
          policy,
          'policy',
          'Expected instance of $policyType',
        );
      }
      return policyCreator(policy);
    };
  }

  /// Creates a security handler based on the `/Filter` value stored in the
  /// encryption dictionary.
  SecurityHandler<ProtectionPolicy>? newSecurityHandlerForFilter(
      String filter) {
    final creator = _filterFactories[filter];
    return creator?.call();
  }

  /// Creates a security handler based on the supplied protection policy.
  SecurityHandler<ProtectionPolicy>? newSecurityHandlerForPolicy(
      ProtectionPolicy policy) {
    final creator = _policyFactories[policy.runtimeType];
    return creator?.call(policy);
  }
}
