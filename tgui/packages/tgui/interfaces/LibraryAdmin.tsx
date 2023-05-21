import { map, sortBy } from 'common/collections';
import { flow } from 'common/fp';
import { capitalize } from 'common/string';
import { useBackend, useLocalState } from '../backend';
import { Box, Button, Dropdown, Input, NoticeBox, Section, Stack, Table, TextArea } from '../components';
import { Window } from '../layouts';
import { PageSelect } from './LibraryConsole';

export const LibraryAdmin = (props, context) => {
  const [modifyMethod, setModifyMethod] = useLocalState(
    context,
    'ModifyMethod',
    null
  );
  return (
    <Window
      title="Admin Library Console"
      theme="admin"
      width={740}
      height={600}>
      {modifyMethod ? <ModifyPage /> : <BookListing />}
    </Window>
  );
};

type ListingData = {
  can_connect: boolean;
  can_db_request: boolean;
  our_page: number;
  page_count: number;
};

const BookListing = (props, context) => {
  const { act, data } = useBackend<ListingData>(context);
  const { can_connect, can_db_request, our_page, page_count } = data;
  if (!can_connect) {
    return (
      <NoticeBox>
        Unable to retrieve book listings. Please contact your system
        administrator for assistance.
      </NoticeBox>
    );
  }
  return (
    <Stack fill vertical justify="space-between">
      <Stack.Item>
        <Box fillPositionedParent bottom="25px">
          <Window.Content scrollable>
            <SearchAndDisplay />
          </Window.Content>
        </Box>
      </Stack.Item>
      <Stack.Item align="center">
        <PageSelect
          minimum_page_count={1}
          page_count={page_count}
          current_page={our_page}
          disabled={!can_db_request}
          call_on_change={(value) =>
            act('switch_page', {
              page: value,
            })
          }
        />
      </Stack.Item>
    </Stack>
  );
};

type Page = {
  author: string;
  category: string;
  title: string;
  id: number;
  deleted: boolean;
};

type DisplayData = {
  can_db_request: boolean;
  categories: string[];
  book_id: number;
  title: string;
  category: string;
  author: string;
  params_changed: boolean;
  view_raw: boolean;
  history: HistoryArray;
  pages: Page[];
};

const SearchAndDisplay = (props, context) => {
  const { act, data } = useBackend<DisplayData>(context);
  const [modifyMethod, setModifyMethod] = useLocalState(
    context,
    'ModifyMethod',
    ''
  );
  const [modifyTarget, setModifyTarget] = useLocalState(
    context,
    'ModifyTarget',
    0
  );
  const {
    can_db_request,
    categories = [],
    book_id,
    title,
    category,
    author,
    params_changed,
    view_raw,
    history,
  } = data;
  const records = flow([
    map((record, i) => ({
      ...record,
      // Generate a unique id
      key: i,
    })),
    sortBy((record) => record.key),
  ])(data.pages);
  return (
    <Section>
      <Stack justify="space-between">
        <Stack.Item pb={0.6}>
          <Stack>
            <Stack.Item>
              <Input
                value={book_id}
                placeholder={book_id === null ? "ID" : book_id}
                mt={0.5}
                width="70px"
                onChange={(e, value) =>
                  act('set_search_id', {
                    id: value,
                  })
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Dropdown
                options={categories}
                selected={category}
                onSelected={(value) =>
                  act('set_search_category', {
                    category: value,
                  })
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Input
                value={title}
                placeholder={title || 'Title'}
                mt={0.5}
                onChange={(e, value) =>
                  act('set_search_title', {
                    title: value,
                  })
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Input
                value={author}
                placeholder={author || 'Author'}
                mt={0.5}
                onChange={(e, value) =>
                  act('set_search_author', {
                    author: value,
                  })
                }
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Button
            textAlign="right"
            onClick={() => act('toggle_raw')}
            color={view_raw ? 'purple' : 'blue'}
            icon={view_raw ? 'theater-masks' : 'glasses'}
            content={view_raw ? 'Raw' : 'Normal'}
          />
          <Button
            disabled={!can_db_request}
            textAlign="right"
            onClick={() => act('search')}
            color={params_changed ? 'good' : ''}
            icon="book">
            Search
          </Button>
          <Button
            disabled={!can_db_request}
            textAlign="right"
            onClick={() => act('clear_data')}
            color="bad"
            icon="fire">
            Reset Search
          </Button>
        </Stack.Item>
      </Stack>
      <Table>
        <Table.Row>
          <Table.Cell fontSize={1.5}>#</Table.Cell>
          <Table.Cell fontSize={1.5}>Category</Table.Cell>
          <Table.Cell fontSize={1.5}>Title</Table.Cell>
          <Table.Cell fontSize={1.5}>Author</Table.Cell>
          <Table.Cell fontSize={1.5}>Un/Hide</Table.Cell>
        </Table.Row>
        {records.map((record) => (
          <Table.Row key={record.key}>
            <Table.Cell>
              <Button
                onClick={() =>
                  act('view_book', {
                    book_id: record.id,
                  })
                }
                icon="book-reader">
                {record.id}
              </Button>
            </Table.Cell>
            <Table.Cell>{record.category}</Table.Cell>
            <Table.Cell>{record.title}</Table.Cell>
            <Table.Cell>{record.author}</Table.Cell>
            <Table.Cell>
              {record.deleted ? (
                <Button
                  onClick={() => {
                    setModifyTarget(record.id);
                    setModifyMethod(ModifyTypes.Restore);
                    if (!history[record.id]) {
                      act('get_history', {
                        book_id: record.id,
                      });
                    }
                  }}
                  icon="undo"
                  color="blue">
                  Unhide
                </Button>
              ) : (
                <Button
                  onClick={() => {
                    setModifyTarget(record.id);
                    setModifyMethod(ModifyTypes.Delete);
                    if (!history[record.id]) {
                      act('get_history', {
                        book_id: record.id,
                      });
                    }
                  }}
                  icon="hammer"
                  color="violet">
                  Hide
                </Button>
              )}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};

const ModifyTypes = {
  Delete: 'delete',
  Restore: 'restore',
};

type HistoryEntry = {
  // The id of this logged action
  id: number;
  // The book id this log applies to
  book: number;
  // The reason this action was enacted
  reason: string;
  // The admin who performed the action
  ckey: string;
  // The time of the action being performed
  datetime: string;
  // The action that ocurred
  action: string;
  // The ip address of the admin who performed the action
  ip_addr: string;
};

type HistoryArray = {
  [key: string]: HistoryEntry[];
};

type ModalData = {
  can_db_request: boolean;
  view_raw: boolean;
  history: HistoryArray;
};

const ModifyPage = (props, context) => {
  const { act, data } = useBackend<ModalData>(context);

  const { can_db_request, view_raw, history } = data;
  const [modifyMethod, setModifyMethod] = useLocalState(
    context,
    'ModifyMethod',
    ''
  );
  const [modifyTarget, setModifyTarget] = useLocalState(
    context,
    'ModifyTarget',
    0
  );
  const [reason, setReason] = useLocalState(context, 'Reason', 'null');

  const entries = history[modifyTarget.toString()]
    ? history[modifyTarget.toString()].sort((a, b) => b.id - a.id)
    : [];

  return (
    <Window.Content scrollable>
      <Stack>
        <Stack.Item fontSize="25px" pb={2}>
          Why do you want to {modifyMethod} this book?
        </Stack.Item>
        <Stack.Item fontSize="17px">
          <Button
            onClick={() =>
              act('view_book', {
                book_id: modifyTarget,
              })
            }
            icon="book-reader">
            View
          </Button>
        </Stack.Item>
        <Stack.Item fontSize="17px">
          <Button
            textAlign="right"
            onClick={() => act('toggle_raw')}
            color={view_raw ? 'purple' : 'blue'}
            icon={view_raw ? 'theater-masks' : 'glasses'}
            content={view_raw ? 'Raw' : 'Normal'}
          />
        </Stack.Item>
      </Stack>
      <TextArea
        fluid
        height="20vh"
        width="100%"
        backgroundColor="black"
        textColor="white"
        onChange={(e, value) => setReason(value)}
      />
      <Stack justify="center" align="center" pt={1} pb={1}>
        <Stack.Item>
          <Button
            disabled={!can_db_request}
            icon="upload"
            content={capitalize(modifyMethod)}
            fontSize="18px"
            color="good"
            onClick={() => {
              switch (modifyMethod) {
                case ModifyTypes.Delete:
                  act('hide_book', {
                    book_id: modifyTarget,
                    delete_reason: reason,
                  });
                  break;
                case ModifyTypes.Restore:
                  act('unhide_book', {
                    book_id: modifyTarget,
                    free_reason: reason,
                  });
                  break;
              }
              setModifyMethod('');
              setModifyTarget(0);
            }}
            lineHeight={2}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="times"
            content="Return"
            fontSize="18px"
            color="bad"
            onClick={() => {
              setModifyMethod('');
              setModifyTarget(0);
            }}
            lineHeight={2}
          />
        </Stack.Item>
      </Stack>
      <Section title="History">
        <Table>
          <Table.Row className="candystripe">
            <Table.Cell fontSize={1.5}>#</Table.Cell>
            <Table.Cell fontSize={1.5} textAlign="center">
              Action
            </Table.Cell>
            <Table.Cell fontSize={1.5} textAlign="center">
              Reason
            </Table.Cell>
            <Table.Cell fontSize={1.5} textAlign="center">
              Admin Key
            </Table.Cell>
            <Table.Cell fontSize={1.5} textAlign="center">
              Datetime
            </Table.Cell>
          </Table.Row>
          {entries.map((entry) => (
            <tr key={entry.id} className="Table__row candystripe">
              <td>{entry.id}</td>
              <td>{capitalize(entry.action)}</td>
              <td className="Table__cell text-center">{entry.reason}</td>
              <td className="Table__cell text-center text-nowrap">
                {entry.ckey}
              </td>
              <td className="Table__cell text-center text-nowrap">
                {entry.datetime}
              </td>
            </tr>
          ))}
        </Table>
      </Section>
    </Window.Content>
  );
};

/*


      */
