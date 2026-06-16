import { useEditableAutomation } from '../useEditableAutomation';
import useAutomationValues from '../useAutomationValues';

vi.mock('../useAutomationValues');

describe('useEditableAutomation', () => {
  beforeEach(() => {
    useAutomationValues.mockReturnValue({
      getConditionDropdownValues: vi.fn(attributeKey => {
        if (attributeKey === 'private_note') {
          return [
            { id: true, name: 'True' },
            { id: false, name: 'False' },
          ];
        }

        if (attributeKey === 'team_id') {
          return [{ id: 1, name: 'Support' }];
        }

        return [];
      }),
      getActionDropdownValues: vi.fn(actionName => {
        if (actionName === 'assign_agent') {
          return [
            { id: 'nil', name: 'None' },
            {
              id: 'last_responding_agent',
              name: 'Last Responding Agent',
            },
            { id: 1, name: 'Agent 1' },
          ];
        }

        return [];
      }),
    });
  });

  it('rehydrates boolean conditions as a single selected option', () => {
    const automation = {
      event_name: 'message_created',
      conditions: [
        {
          attribute_key: 'private_note',
          filter_operator: 'equal_to',
          values: [false],
          query_operator: null,
        },
      ],
      actions: [],
    };
    const automationTypes = {
      message_created: {
        conditions: [{ key: 'private_note', inputType: 'search_select' }],
      },
    };

    const { formatAutomation } = useEditableAutomation();
    const result = formatAutomation(automation, [], automationTypes, []);

    expect(result.conditions).toEqual([
      {
        attribute_key: 'private_note',
        filter_operator: 'equal_to',
        values: { id: false, name: 'False' },
        query_operator: 'and',
      },
    ]);
  });

  it('rehydrates last responding agent as a selected action option', () => {
    const automation = {
      event_name: 'conversation_created',
      conditions: [],
      actions: [
        {
          action_name: 'assign_agent',
          action_params: ['last_responding_agent'],
        },
      ],
    };
    const automationActionTypes = [
      { key: 'assign_agent', inputType: 'search_select' },
    ];

    const { formatAutomation } = useEditableAutomation();
    const result = formatAutomation(automation, [], {}, automationActionTypes);

    expect(result.actions).toEqual([
      {
        action_name: 'assign_agent',
        action_params: [
          {
            id: 'last_responding_agent',
            name: 'Last Responding Agent',
          },
        ],
      },
    ]);
  });

  it('rehydrates attribute_changed conditions with from/to options', () => {
    const automation = {
      event_name: 'conversation_updated',
      conditions: [
        {
          attribute_key: 'team_id',
          filter_operator: 'attribute_changed',
          values: {
            from: ['any'],
            to: [1],
          },
          query_operator: null,
        },
      ],
      actions: [],
    };
    const automationTypes = {
      conversation_updated: {
        conditions: [{ key: 'team_id', inputType: 'search_select' }],
      },
    };

    const { formatAutomation } = useEditableAutomation();
    const result = formatAutomation(automation, [], automationTypes, []);

    expect(result.conditions).toEqual([
      {
        attribute_key: 'team_id',
        filter_operator: 'attribute_changed',
        values: {
          from: { id: 'any', name: 'Any' },
          to: { id: 1, name: 'Support' },
        },
        query_operator: 'and',
      },
    ]);
  });
});
