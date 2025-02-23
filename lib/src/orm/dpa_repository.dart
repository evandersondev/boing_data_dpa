abstract class DpaRepository<T, ID> {
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<void> save(T entity);
  Future<void> saveAll(List<T> entities);
  Future<void> deleteById(ID id);
  Future<void> deleteAll();
  Future<int> count();
}
