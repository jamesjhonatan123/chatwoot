import wootConstants from 'dashboard/constants/globals';

const ASSIGNEE_ATTRIBUTE_KEY = 'assignee_id';

const isAssigneeFilter = filter => filter.attributeKey === ASSIGNEE_ATTRIBUTE_KEY;

const buildAssigneeFilter = (assigneeType, currentUserDetails, queryOperator) => {
  if (assigneeType === wootConstants.ASSIGNEE_TYPE.ALL) {
    return null;
  }

  if (assigneeType === wootConstants.ASSIGNEE_TYPE.UNASSIGNED) {
    return {
      attributeKey: ASSIGNEE_ATTRIBUTE_KEY,
      attributeModel: 'standard',
      filterOperator: 'is_not_present',
      values: [],
      queryOperator,
      customAttributeType: '',
    };
  }

  return {
    attributeKey: ASSIGNEE_ATTRIBUTE_KEY,
    attributeModel: 'standard',
    filterOperator: 'equal_to',
    values: currentUserDetails,
    queryOperator,
    customAttributeType: '',
  };
};

const normalizeQueryOperators = filters => {
  return filters.map((filter, index) => ({
    ...filter,
    queryOperator:
      index === filters.length - 1 ? undefined : filter.queryOperator || 'and',
  }));
};

export const syncFiltersWithAssigneeTab = (
  filters,
  assigneeType,
  currentUserDetails
) => {
  const currentFilters = [...filters];
  const assigneeFilterIndex = currentFilters.findIndex(isAssigneeFilter);

  if (assigneeFilterIndex !== -1) {
    const currentAssigneeFilter = currentFilters[assigneeFilterIndex];
    const nextAssigneeFilter = buildAssigneeFilter(
      assigneeType,
      currentUserDetails,
      currentAssigneeFilter.queryOperator
    );

    if (!nextAssigneeFilter) {
      currentFilters.splice(assigneeFilterIndex, 1);
      return normalizeQueryOperators(currentFilters);
    }

    currentFilters.splice(assigneeFilterIndex, 1, nextAssigneeFilter);
    return normalizeQueryOperators(currentFilters);
  }

  const nextAssigneeFilter = buildAssigneeFilter(
    assigneeType,
    currentUserDetails,
    undefined
  );

  if (!nextAssigneeFilter) {
    return normalizeQueryOperators(currentFilters);
  }

  return normalizeQueryOperators([...currentFilters, nextAssigneeFilter]);
};
