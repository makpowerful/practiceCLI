import { Page, Locator, expect } from '@playwright/test';

export class DashboardPage {
  readonly page: Page;
  readonly productCards: Locator;
  readonly cartButton: Locator;
  readonly toast: Locator;

  constructor(page: Page) {
    this.page = page;
    this.productCards = page.locator('.card-body');
    this.cartButton = page.locator("button[routerlink*='cart']");
    this.toast = page.locator('#toast-container');
  }

  async getAllProductNames(): Promise<string[]> {
    await this.productCards.first().waitFor();
    return (await this.productCards.locator('b').allTextContents()).map(n => n.trim());
  }

  async addProductToCart(name: string) {
    const card = this.productCards.filter({ has: this.page.locator('b', { hasText: name }) });
    await card.getByRole('button', { name: 'Add To Cart' }).click();
    await expect(this.toast).toContainText('Product Added To Cart');
    await this.toast.waitFor({ state: 'hidden' });
  }

  /** Picks `count` distinct products at random, adds them to the cart and returns their names. */
  async addRandomProductsToCart(count: number): Promise<string[]> {
    const all = await this.getAllProductNames();
    if (all.length < count) {
      throw new Error(`Only ${all.length} products available, cannot pick ${count}`);
    }
    const picked = [...all].sort(() => Math.random() - 0.5).slice(0, count);
    for (const name of picked) {
      await this.addProductToCart(name);
    }
    return picked;
  }

  async goToCart() {
    await this.cartButton.click();
    await expect(this.page).toHaveURL(/#\/ajklkdljkdsfksdf\/cart/);
  }
}
