import { Page, Locator, expect } from '@playwright/test';

export class CartPage {
  readonly page: Page;
  readonly cartItems: Locator;
  readonly itemNames: Locator;
  readonly deleteButtons: Locator;
  readonly emptyCartMessage: Locator;
  readonly checkoutButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.cartItems = page.locator('.cartWrap li.items');
    this.itemNames = page.locator('.cartWrap li.items h3');
    this.deleteButtons = page.locator('.cartWrap .btn');
    this.emptyCartMessage = page.getByText('No Products in Your Cart');
    this.checkoutButton = page.getByRole('button', { name: 'Checkout' });
  }

  /** Waits until the cart has rendered either its items or the empty-cart message. */
  async waitForLoad() {
    await expect(this.cartItems.first().or(this.emptyCartMessage)).toBeVisible();
  }

  async clearCart() {
    await this.waitForLoad();
    let remaining = await this.deleteButtons.count();
    while (remaining > 0) {
      await this.deleteButtons.first().click();
      await expect(this.deleteButtons).toHaveCount(remaining - 1);
      remaining--;
    }
  }

  async getItemNames(): Promise<string[]> {
    await this.waitForLoad();
    return (await this.itemNames.allTextContents()).map(n => n.trim());
  }

  async checkout() {
    await this.checkoutButton.click();
    await expect(this.page).toHaveURL(/#\/dashboard\/order/);
  }
}
