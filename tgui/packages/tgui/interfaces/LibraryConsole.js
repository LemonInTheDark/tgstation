import { map, sortBy } from 'common/collections';
import { flow } from 'common/fp';
import { useBackend } from '../backend';
import { Box, Button, Dropdown, Flex, Input, NoticeBox, Section, Stack, Table } from '../components';
import { TableCell } from '../components/Table';
import { Window } from '../layouts';

export const LibraryConsole = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    show_dropdown,
  } = data;
  return (
    <Window
      title="Library Terminal"
      width={880}
      height={518}>
      <PopoutMenu />
      <Box fillPositionedParent left={show_dropdown ? "164px" : "50px"}>
        <PageDisplay />
      </Box>
    </Window>
  );
};

export const PopoutMenu = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    screen_state,
    show_dropdown,
    display_lore,
  } = data;
  return (
    <Section fill={1} maxWidth={show_dropdown ? "150px" : "36px"}>
      <Stack vertical={1} fill={1}>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('toggle_dropdown')}
            icon={show_dropdown === 1 ? 'chevron-left' : 'chevron-right'}
            tooltip={!show_dropdown && "Expand"}
            content={!!show_dropdown && "Collapse"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 0,
            })}
            color={screen_state === 0 ? 'good' : ''}
            icon={'list'}
            tooltip={!show_dropdown && "Inventory"}
            content={!!show_dropdown && "Inventory"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 1,
            })}
            color={screen_state === 1 ? 'good' : ''}
            icon={'calendar'}
            tooltip={!show_dropdown && "Checkout Listing"}
            content={!!show_dropdown && "Checkout Listing"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 2,
            })}
            color={screen_state === 2 ? 'good' : ''}
            icon={'barcode'}
            tooltip={!show_dropdown && "Checkout"}
            content={!!show_dropdown && "Checkout"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 3,
            })}
            color={screen_state === 3 ? 'good' : ''}
            icon={'server'}
            tooltip={!show_dropdown && "Archive"}
            content={!!show_dropdown && "Archive"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 4,
            })}
            color={screen_state === 4 ? 'good' : ''}
            icon={'upload'}
            tooltip={!show_dropdown && "Upload"}
            content={!!show_dropdown && "Upload"} />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            fontSize="13px"
            onClick={() => act('set_screen', {
              screen_index: 5,
            })}
            color={screen_state === 5 ? 'good' : ''}
            icon={'print'}
            tooltip={!show_dropdown && "Print"}
            content={!!show_dropdown && "Print"} />
        </Stack.Item>
        <Stack.Item>
          {!!display_lore && (
            <Button
              fluid
              fontSize="13px"
              onClick={() => act('set_screen', {
                screen_index: 6,
              })}
              color={screen_state === 6 ? 'bad' : 'black'}
              icon={'question'}
              tooltip={!show_dropdown && "Forbidden Lore"}
              content={!!show_dropdown && "Forbidden Lore"} />
          )}
        </Stack.Item>
      </Stack>
    </Section>
  );
};

export const PageDisplay = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    screen_state,
  } = data;
  if (screen_state === 0) { // Inventory
    return (
      <Inventory />
    );
  }
  if (screen_state === 1) { // Checkout table
    return (
      <CheckoutList />
    );
  }
  if (screen_state === 2) { // Checkout page
    return (
      <Checkout />
    );
  }
  if (screen_state === 3) { // Inventory
    return (
      <Archive />
    );
  }
  if (screen_state === 4) { // Inventory
    return (
      <Upload />
    );
  }
  if (screen_state === 5) { // Inventory
    return (
      <Print />
    );
  }
  if (screen_state === 6) { // Inventory
    return (
      <Forbidden />
    );
  }
};

export const Inventory = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    inventory_page_count,
    inventory_page,
    has_inventory,
  } = data;
  if (!has_inventory) {
    return (
      <NoticeBox>
        No Book Records detected. Scan some in to see more
      </NoticeBox>
    );
  }
  return (
    <Stack
      fill={1}
      vertical={1}
      justify={"space-between"}>
      <Stack.Item>
        <Box fillPositionedParent bottom="25px">
          <Window.Content
            fitted={1}
            scrollable={1}>
            <InventoryDetails />
          </Window.Content>
        </Box>
      </Stack.Item>
      <Stack.Item
        align={"center"}>
        <PageSelect
          minimum_page_count={1}
          page_count={inventory_page_count}
          current_page={inventory_page}
          call_on_change={(value) => act("switch_inventory_page", {
            page: value,
          })} />
      </Stack.Item>
    </Stack>
  );
};

export const InventoryDetails = (props, context) => {
  const { act, data } = useBackend(context);
  const inventory = flow([
    map((book, i) => ({
      ...book,
      // Generate a unique id
      key: i,
    })),
    sortBy(book => book.key),
  ])(data.inventory);
  return (
    <Section>
      <Table>
        <Table.Row>
          <Table.Cell
            fontSize={1.5}>
            Remove
          </Table.Cell>
          <Table.Cell
            fontSize={1.5}>
            Title
          </Table.Cell>
          <Table.Cell
            fontSize={1.5}>
            Author
          </Table.Cell>
        </Table.Row>
        {inventory.map(book => (
          <Table.Row key={book.key}>
            <Table.Cell>
              <Button
                color={'bad'}
                onClick={() => act('inventory_remove', {
                  book_id: book.id,
                })}
                icon={'times'}>
                Clear Record
              </Button>
            </Table.Cell>
            <Table.Cell>
              {book.title}
            </Table.Cell>
            <Table.Cell>
              {book.author}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};

export const CheckoutList = (props, context) => {
  const { act, data } = useBackend(context);

};

export const Checkout = (props, context) => {
  const { act, data } = useBackend(context);

};

export const Archive = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    page_count,
    our_page,
    can_connect,
  } = data;
  if (!can_connect) {
    return (
      <NoticeBox>
        Unable to retrieve book listings.
        Please contact your system administrator for assistance.
      </NoticeBox>
    );
  }
  return (
    <Stack
      fill={1}
      vertical={1}
      justify={"space-between"}>
      <Stack.Item>
        <Box fillPositionedParent bottom="25px">
          <Window.Content
            fitted={1}
            scrollable={1}>
            <SearchAndDisplay />
          </Window.Content>
        </Box>
      </Stack.Item>
      <Stack.Item
        align={"center"}>
        <PageSelect
          minimum_page_count={1}
          page_count={page_count}
          current_page={our_page}
          call_on_change={(value) => act("switch-page", {
            page: value,
          })} />
      </Stack.Item>
    </Stack>
  );
};

export const SearchAndDisplay = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    categories = [],
    title,
    category,
    author,
    params_changed,
  } = data;
  const records = flow([
    map((record, i) => ({
      ...record,
      // Generate a unique id
      key: i,
    })),
    sortBy(record => record.key),
  ])(data.pages);
  return (
    <Section>
      <Stack justify={"space-between"}>
        <Stack.Item>
          <Stack>
            <Stack.Item>
              <Dropdown
                options={categories}
                selected={category}
                onSelected={(value) => act('set-category', {
                  category: value,
                })} />
            </Stack.Item>
            <Stack.Item>
              <Input
                value={title}
                placeholder={title || "Title"}
                mt={0.5}
                onChange={(e, value) => act("set-title", {
                  title: value,
                })} />
            </Stack.Item>
            <Stack.Item>
              <Input
                value={author}
                placeholder={author || "Author"}
                mt={0.5}
                onChange={(e, value) => act("set-author", {
                  author: value,
                })} />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Button
            textAlign={'right'}
            onClick={() => act('search')}
            color={params_changed ? 'good' : ''}
            icon={'book'}>
            Search
          </Button>
          <Button
            textAlign={'right'}
            onClick={() => act('clear-data')}
            color={'bad'}
            icon={'fire'}>
            Reset Search
          </Button>
        </Stack.Item>
      </Stack>
      <Table>
        <Table.Row>
          <Table.Cell
            fontSize={1.5}>
            Print
          </Table.Cell>
          <Table.Cell
            fontSize={1.5}>
            #
          </Table.Cell>
          <TableCell
            fontSize={1.5}>
            Category
          </TableCell>
          <Table.Cell
            fontSize={1.5}>
            Title
          </Table.Cell>
          <Table.Cell
            fontSize={1.5}>
            Author
          </Table.Cell>
        </Table.Row>
        {records.map(record => (
          <Table.Row key={record.key}>
            <Table.Cell>
              <Button
                onClick={() => act('print_book', {
                  book_id: record.id,
                })}
                icon={'print'} />
            </Table.Cell>
            <Table.Cell>
              {record.id}
            </Table.Cell>
            <Table.Cell>
              {record.category}
            </Table.Cell>
            <Table.Cell>
              {record.title}
            </Table.Cell>
            <Table.Cell>
              {record.author}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};

export const Upload = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    has_scanner,
    has_cache,
    categories,
    cache_title,
    cache_author,
    upload_category,
  } = data;
  if (!has_scanner) {
    return (
      <NoticeBox>
        No nearby scanner detected, construct one to continue.
      </NoticeBox>
    );
  }
  if (!has_cache) {
    return (
      <NoticeBox>
        Scan in a book to upload.
      </NoticeBox>
    );
  }
  return (
    <Flex>
      <Flex.Item>
        <Button
          fluid
          icon="server"
          content="Archive"
          fontSize="30px"
          lineHeight={2}
          onClick={() => act('upload')} />
      </Flex.Item>
      <Flex.Item>
        <Button
          fluid
          icon="newspaper"
          content="Newscaster"
          fontSize="30px"
          lineHeight={2}
          onClick={() => act('news_post')} />
      </Flex.Item>
      <Flex.Item align="center">
        <Dropdown
          options={categories}
          selected={upload_category}
          onSelected={(value) => act('set_upload_category', {
            category: value,
          })} />
      </Flex.Item>
      <Flex.Item align="center">
        <Input
          value={cache_title}
          placeholder={cache_title || "Title"}
          mt={0.5}
          onChange={(e, value) => act("set_title", {
            title: value,
          })} />
      </Flex.Item>
      <Flex.Item align="center">
        <Input
          value={cache_author}
          placeholder={cache_author || "Author"}
          mt={0.5}
          onChange={(e, value) => act("set_author", {
            author: value,
          })} />
      </Flex.Item>
    </Flex>
  );
};

export const Print = (props, context) => {
  const { act, data } = useBackend(context);

};

export const Forbidden = (props, context) => {
  const { act, data } = useBackend(context);

};

export const PageSelect = (props) => {
  const {
    minimum_page_count,
    page_count,
    current_page,
    call_on_change,
  } = props;
  return (
    <Stack>
      <Stack.Item>
        <Button
          disabled={current_page === minimum_page_count}
          icon={'angle-double-left'}
          onClick={() => call_on_change(minimum_page_count)} />
      </Stack.Item>
      <Stack.Item>
        <Button
          disabled={current_page === minimum_page_count}
          icon={'chevron-left'}
          onClick={() => call_on_change(current_page - 1)} />
      </Stack.Item>
      <Stack.Item>
        <Input
          placeholder={current_page + "/" + page_count}
          onChange={(e, value) => call_on_change(value)} />
      </Stack.Item>
      <Stack.Item>
        <Button
          disabled={current_page === page_count}
          icon={'chevron-right'}
          onClick={() => call_on_change(current_page + 1)} />
      </Stack.Item>
      <Stack.Item>
        <Button
          disabled={current_page === page_count}
          icon={'angle-double-right'}
          onClick={() => call_on_change(page_count)} />
      </Stack.Item>
    </Stack>
  );
};
