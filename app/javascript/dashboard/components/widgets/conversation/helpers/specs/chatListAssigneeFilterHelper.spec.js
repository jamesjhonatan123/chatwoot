import { describe, expect, it } from 'vitest';
import wootConstants from 'dashboard/constants/globals';

import { syncFiltersWithAssigneeTab } from '../chatListAssigneeFilterHelper';

describe('syncFiltersWithAssigneeTab', () => {
  const currentUser = { id: 7, name: 'Alex' };

  it('replaces an existing assignee filter and preserves its position', () => {
    const filters = [
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: 'and',
      },
      {
        attributeKey: 'assignee_id',
        filterOperator: 'equal_to',
        values: { id: 7, name: 'Alex' },
        queryOperator: undefined,
      },
    ];

    expect(
      syncFiltersWithAssigneeTab(
        filters,
        wootConstants.ASSIGNEE_TYPE.UNASSIGNED,
        currentUser
      )
    ).toEqual([
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: 'and',
      },
      {
        attributeKey: 'assignee_id',
        attributeModel: 'standard',
        filterOperator: 'is_not_present',
        values: [],
        queryOperator: undefined,
        customAttributeType: '',
      },
    ]);
  });

  it('removes the assignee filter when switching to all', () => {
    const filters = [
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: 'and',
      },
      {
        attributeKey: 'assignee_id',
        filterOperator: 'equal_to',
        values: { id: 7, name: 'Alex' },
        queryOperator: undefined,
      },
    ];

    expect(
      syncFiltersWithAssigneeTab(
        filters,
        wootConstants.ASSIGNEE_TYPE.ALL,
        currentUser
      )
    ).toEqual([
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: undefined,
      },
    ]);
  });

  it('appends a mine filter when the current filters do not include assignee', () => {
    const filters = [
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: undefined,
      },
    ];

    expect(
      syncFiltersWithAssigneeTab(
        filters,
        wootConstants.ASSIGNEE_TYPE.ME,
        currentUser
      )
    ).toEqual([
      {
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
        queryOperator: 'and',
      },
      {
        attributeKey: 'assignee_id',
        attributeModel: 'standard',
        filterOperator: 'equal_to',
        values: { id: 7, name: 'Alex' },
        queryOperator: undefined,
        customAttributeType: '',
      },
    ]);
  });
});
